# Architecture review

Reviewed on 2026-10-01.

## Verdict

The project is in a good place for a small menu-bar app. It needs targeted reliability work, not a rewrite or a new architecture.

Keep the composition root in `AppDelegate`, the observable model, the small SwiftUI views, and the protocol-based service boundaries. The highest-value changes are in audio reads, recovery state, and device monitoring.

## What works well

- `AppDelegate` creates the concrete dependencies in one place. Views do not construct services or access Core Audio directly.
- `MicMuterModel` uses `@Observable`, keeps mutations behind methods, and exposes read-only state to views.
- `@MainActor` keeps AppKit, observable state, and audio control operations serialized. There is no audio processing callback doing UI or storage work.
- The AppKit status item is appropriate for the custom left-click/right-click behavior. Replacing it with `MenuBarExtra` is not necessary.
- `SMAppService` is the right Launch at Login API. `LSUIElement` is appropriate for an app without a Dock icon.
- Stable device UIDs are used for selection and persistence instead of transient Core Audio object IDs.
- Volume snapshots include channel elements, and failed writes attempt rollback while keeping recovery data when rollback fails.
- The SwiftPM tests reuse production sources, and CI also builds the actual app and its release package.

## Findings, in priority order

### 1. High: failed or incomplete reads can lose recovery data or falsely confirm mute

Files: `Sources/MicMuter/Audio/CoreAudioDeviceManager.swift`, `Sources/MicMuter/Audio/CoreAudioDeviceManager+Properties.swift`.

`volumeValues(for:)` drops failed channel reads with `compactMap`. The caller cannot tell whether it received every channel, a partial result, or no result because of a read error.

- `reconcileStaleFallbackState(for:)` treats an empty result as evidence that the input is not zero and deletes the saved levels. A temporary read failure can therefore prevent a later unmute from restoring the microphone.
- `status(for:)` accepts any nonempty set of zero values as confirmation of mute. If only one of two channels is readable, it can show "muted" without knowing the other channel's level.

Both behaviors were confirmed with temporary tests using simulated property failures. No physical microphone failure was induced.

Recommendation: return a complete, validated volume snapshot or an explicit read failure. Retain recovery data on unreadable or incomplete input. Report an unknown state rather than claiming mute is confirmed. Clear recovery data only after a successful read proves an external change.

### 2. High: failed unmute loses the user's intended action

Files: `Sources/MicMuter/Features/Mute/MicMuterModel.swift`, `Sources/MicMuter/Audio/CoreAudioDeviceManager.swift`, `Sources/MicMuter/Services/Storage/VolumeStore.swift`.

After a partial restore failure, the audio manager reports `.unknown`. The model turns every state other than `.muted` into a request to mute. On the next click, the manager restores the saved levels and immediately zeros them again.

Confirmed with a temporary test through `MicMuterModel` and the real manager's control logic: mute, fail an unmute channel write, click again. The result is muted, not a completed unmute.

Recommendation: make recovery an explicit operation/state instead of encoding it as ordinary `.unknown`. Preserve the pending action and let a retry finish it. Store the recovery phase and saved levels together rather than relying on three independently written UserDefaults keys. Preserve compatibility with existing saved data.

### 3. High: monitoring does not match the controls the adapter supports

Files: `Sources/MicMuter/Audio/CoreAudioDeviceManager.swift`, `Sources/MicMuter/Audio/CoreAudioDeviceManager+Listeners.swift`.

Volume reads and writes support per-channel elements, but listeners subscribe only to element zero. Changes to channel-only controls are not covered by those registrations, which can leave the icon and fallback state stale after external changes.

Listener reconciliation also compares only UIDs. If the same UID is returned with a different object ID after a device or audio-service restart, the existing listeners are not replaced. Failed listener registrations are silently ignored and are not retried for devices already in the list.

Recommendation: monitor the actual supported elements or use an element wildcard for notifications. Reconcile registrations against both UID and object ID, retry missing registrations, and expose/log failures. Add an explicit monitoring teardown that unregisters system and device listeners. The current app-lifetime ownership limits teardown impact, but weak captures do not unregister Core Audio blocks.

These are source-level findings checked against the Core Audio SDK's property and listener definitions; hardware hot-plug/restart behavior was not tested.

### 4. Medium: every audio event triggers too much unrelated work

Files: `Sources/MicMuter/Audio/CoreAudioDeviceManager+Listeners.swift`, `Sources/MicMuter/Audio/CoreAudioDeviceManager.swift`, `Sources/MicMuter/Features/Mute/MicMuterModel.swift`.

A mute or volume notification enumerates all devices, reads names and stream configurations, reconciles every device's fallback state, and schedules another main-actor task to update the model. That update also persists the selected name even when it has not changed. A toggle adds an immediate refresh on top of callback-driven updates.

Recommendation: separate topology changes from property changes, coalesce queued notifications, and persist names only when changed. Publish a consistent selected-device snapshot containing status, capability, and recovery information so SwiftUI getters do not repeatedly query hardware. Keep operations serialized; moving Core Audio to a separate executor is only justified if profiling shows blocking UI work.

### 5. Medium: Launch at Login loses macOS approval and external-change state

Files: `Sources/MicMuter/Services/System/SMLoginItemService.swift`, `Sources/MicMuter/Features/Mute/MicMuterModel.swift`, `Sources/MicMuter/UI/MenuBar/SettingsRowsView.swift`.

The service reduces `SMAppService.Status` to a Boolean. `.requiresApproval` is indistinguishable from disabled, and the model refreshes it only at launch or after its own setting changes. Changes in System Settings can leave the checkbox stale.

Recommendation: expose enabled, disabled, and approval-required states. Refresh when opening the popover or returning from System Settings, and provide a clear approval message with a way to open Login Items settings.

### 6. Low: the missing-asset fallback is not a fallback

Files: `Sources/MicMuter/UI/MenuBar/MenuBarIcon.swift`, `Sources/MicMuter/UI/Components/MicGlyph.swift`.

When the microphone asset is missing, `fallbackImage(for:)` calls `MicGlyph.draw`, which loads the same missing asset and returns without drawing. The result is a blank image. The drawing path also duplicates glyph-fitting calculations.

Recommendation: use an independent SF Symbol fallback, or remove this path if asset availability is enforced during the build. Consolidate fitting logic if both rendering paths remain.

## Tests and build boundaries

The existing 27 tests passed, as did lint and the Xcode Debug build. Complete strict-concurrency checking also passed for the core tests and app build. Swift 5 language mode is not itself a defect, but enabling strict-concurrency checks in normal builds/CI would protect these boundaries.

The existing tests cover the model and mute adapter separately. They do not cover discovery/listener registration, physical hot-plug behavior, or the combined model/adapter recovery flow. The temporary review tests exposed findings 1 and 2 and were removed so this comment-only cleanup does not leave a failing test suite.

For the reliability work, add permanent regressions for those cases, listener replacement/retry, default-device changes, reconnection, and restart with saved fallback state. Add a macOS smoke-test checklist for clicks, shortcuts, popover dismissal, HUD behavior in full-screen Spaces, VoiceOver, and Login Items approval. Start bug fixes with an end-to-end reproduction matching the user's flow.

The SwiftPM core is a testing boundary, not a module consumed by the Xcode app; Xcode compiles the same files directly. This is acceptable at this size. If source-list drift becomes a problem, use one shared core target, but do not add a framework split just for architectural appearance.

## Recommended scope

1. Fix incomplete-read handling and retry intent, with regression tests.
2. Make monitoring reliable across per-channel changes and object-ID replacement.
3. Reduce notification work and expose a coherent observed device state.
4. Improve Login Items status and simplify the icon fallback.

No DI container, generic repository layer, extra view-model hierarchy, or broad folder reshuffle is needed. `MicMuterModel` is still small enough to own this feature and its settings. Developer ID signing, hardened runtime, and notarization are worthwhile for public distribution, but are separate from the architecture fixes and the documented ad-hoc release policy.

## Changes made during this review

Removed comments that repeated names or explained routine dependency injection, unnecessary section markers, and the misleading missing-asset comment. Kept the SwiftPM tools-version directive and short comments explaining non-obvious selection/recovery semantics. No runtime behavior changed.

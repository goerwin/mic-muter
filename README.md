# Mic Muter

<p align="center">
  <img src="Resources/readme-icon.png" width="128" alt="Mic Muter icon">
</p>

A menu-bar-only macOS app that mutes and unmutes the microphone you select. Click the menu bar icon, or assign a global shortcut.

## Features

- **Menu bar only.** No dock icon and no main window. Left-click to toggle mute; right-click opens the popover, where the device picker, shortcut recorder, and Launch at Login live.
- **Any input device.** Pick a microphone, or leave it on System Default to follow whatever macOS considers current. The list updates when devices come and go.
- **Real mute, with a fallback.** Mic Muter sets the device's own mute control when one exists. Devices exposing only a volume control, such as many webcams, are muted by dropping their input level to zero, and the previous level is restored on unmute.
- **Six-state icon.** Muted, unmuted, input-silent, unknown, unsupported, and disconnected, so a device that cannot be muted never looks like a working one.
- **Optional HUD.** Off by default. Turn on "Show HUD on Toggle" and each toggle briefly shows the new state and device name in the center of the screen, so you get confirmation without opening the popover.
- **Accessible.** Every state has its own spoken description, and the status item is labelled for VoiceOver.

## Installing

Requires macOS 14 or later. Download `MicMuter-<version>.dmg` from the Releases page, drag `Mic Muter.app` to `/Applications`, and open it.

Use **Check for Updates…** in the popover to find and install the latest release.

GitHub releases are signed with the same Apple Development certificate used by Key Remapper, but are not notarized. macOS may block the first launch. Open **System Settings > Privacy & Security** and click **Open Anyway**; this is needed once per version. macOS 15 removed the right-click > Open shortcut, so the System Settings step is the only route.

## Development

Needs Xcode and `swift-format`.

### Architecture

- `App/` is the composition root and AppKit status-item bridge.
- `Features/Mute/` contains the observable model and pure status mapping.
- `Audio/` owns the Core Audio adapter and audio-domain types; the model uses `AudioDeviceManaging`, while property I/O and monitoring are injectable through `AudioDevicePropertyAccess` and `AudioDeviceMonitoring`.
- `Services/Storage/` owns UserDefaults persistence; `Services/System/` wraps login-item and shortcut APIs.
- `State/` holds presentation state, while `UI/` contains the menu-bar, HUD, and reusable SwiftUI views.
- `Tests/MicMuterCoreTests/` exercises model behavior, status mapping, storage, mute recovery, and monitoring with simulated devices. `Tests/MicMuterAppTests/` checks the menu-bar icon without bundled assets.

`AppDelegate` wires the concrete services into `MicMuterModel`. The model depends on protocols rather than AppKit, ServiceManagement, or UserDefaults directly. The SwiftPM core target excludes the app and UI so the same non-UI code can be tested independently; the app itself is built by the Xcode project.

- `make build` builds the app with Xcode.
- `make test` runs core tests and the AppKit icon smoke test. Interactive checks are listed in `Tests/MANUAL_TESTS.md`.
- `make lint` checks Swift sources with `swift-format`.
- `make install` builds from source and replaces `/Applications/Mic Muter.app`, then opens it. macOS may request an administrator password.
- `make release VERSION=1.2.0` builds a universal `dist/MicMuter-1.2.0.dmg`. `VERSION` defaults to `1.0.0`.

`make install` and `make release` use ad-hoc signing by default. GitHub releases use the Apple Development certificate so Sparkle can verify updates between versions.

## Releases

Pushing a `vMAJOR.MINOR.PATCH` tag builds a universal DMG and attaches it to a GitHub Release. The tag is the only source of truth for the version.

Run `make release-patch`, `make release-minor`, or `make release-major`. These targets call `Scripts/release.sh`, which fetches the tags, bumps the latest stable version, then asks for confirmation before pushing a lightweight tag to `origin`. Keep your working tree clean first.

Or trigger it from the Actions tab via *Release* > *Run workflow* with the tag you want.

Each release includes `MicMuter-<version>.dmg` (Apple silicon and Intel), `MicMuter-<version>-SHA256SUMS`, and `appcast.xml` for Sparkle updates. Verify the DMG with `shasum -c MicMuter-<version>-SHA256SUMS`.

The release workflow needs these repository secrets:

- `MAC_APP_CERTIFICATE`: the signing identity name.
- `MAC_BUILD_CERTIFICATE_BASE64`: the signing certificate (`.p12`) encoded as base64.
- `MAC_BUILD_CERTIFICATE_BASE64_PASSWORD`: the `.p12` password.
- `SPARKLE_PRIVATE_KEY`: the private EdDSA key whose public key matches `SUPublicEDKey` in `Resources/Info.plist`.

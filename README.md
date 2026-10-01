# Mic Muter

A menu-bar-only macOS app for toggling the selected microphone with a button or global shortcut.

## Requirements

- macOS 14 or later
- Xcode with Swift and `swift-format`

## Commands

- `make build` builds the app with Xcode.
- `make test` runs unit tests for mute state presentation and accessibility labels.
- `make lint` checks Swift sources with `swift-format`.
- `make install` builds from source and replaces `/Applications/Mic Muter.app`, then opens it. macOS may request an administrator password.
- `make release VERSION=1.2.0` builds a universal `dist/Mic Muter.dmg`. `VERSION` defaults to `1.0.0`.

`make install` and `make release` both ad-hoc sign, so the app runs locally without a certificate.

## Releases

Pushing a `vMAJOR.MINOR.PATCH` tag builds a universal DMG and attaches it to a GitHub Release. The tag is the only source of truth for the version.

```sh
git tag v1.0.0 && git push origin v1.0.0
```

Or trigger it from the Actions tab via *Release* > *Run workflow* with the tag you want.

Each release has two assets: `Mic Muter.dmg` (Apple silicon and Intel) and `SHA256SUMS`, which verifies with `shasum -c SHA256SUMS`.

### Release notes

Generated automatically from the commits between the new tag and the previous one, so there is nothing to write. `feat:` and `fix:` subjects are grouped under those headings; anything else is listed verbatim. Each line links to its commit. Keep commit subjects descriptive, since they become the release body.

## Installing

Download `Mic Muter.dmg` from the Releases page, drag `Mic Muter.app` to `/Applications`, and open it.

Releases are ad-hoc signed rather than notarized, so macOS blocks the first launch. Open **System Settings > Privacy & Security** and click **Open Anyway**; this is needed once per version. macOS 15 removed the right-click > Open shortcut, so the System Settings step is the only route.

Publishing to Homebrew is not an option: since 2026-09-01 casks failing Gatekeeper checks are disabled, which requires signing with a paid Apple Developer Program membership.

## Features

- **Menu bar only.** No dock icon and no main window; the status item and its popover are the whole interface.
- **Mute from the menu bar.** Click the status item to toggle mute, or assign a global shortcut and mute without touching the menu bar at all. The shortcut starts unassigned; record one in the popover.
- **Right-click for options.** Right-clicking the status item opens the popover, where the device picker, shortcut recorder, and Launch at Login live.
- **Any input device.** Pick the microphone to control, or leave it on System Default to follow whatever macOS considers current. The list updates when devices are plugged in or removed.
- **Real mute, with a fallback.** Mic Muter sets the device's own mute control when one exists. Devices that expose only a volume control, such as many webcams, are muted by dropping their input level to zero instead, and the previous level is restored on unmute.
- **Six-state icon.** The status item distinguishes muted, unmuted, input-silent, unknown, unsupported, and disconnected, so a device that cannot be muted never looks like a working one.
- **Launch at Login.** Optional and off by default, using `SMAppService`.
- **Accessible.** Every state has its own spoken description and the status item is labelled for VoiceOver.

Mic Muter reads the system's Core Audio mute state. It cannot see per-app mute toggles inside Zoom, Teams, or similar conferencing software, since those are private to those apps.

The unit tests cover state-to-icon and accessibility mapping. They do not exercise microphone hardware.

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

## Installing

Download `Mic Muter.dmg` from the Releases page, drag `Mic Muter.app` to `/Applications`, and open it.

Releases are ad-hoc signed rather than notarized, so macOS blocks the first launch. Open **System Settings > Privacy & Security** and click **Open Anyway**; this is needed once per version. macOS 15 removed the right-click > Open shortcut, so the System Settings step is the only route.

Publishing to Homebrew is not an option: since 2026-09-01 casks failing Gatekeeper checks are disabled, which requires signing with a paid Apple Developer Program membership.

## Usage

The shortcut starts unassigned. Choose one in the app's shortcut recorder. Launch at Login is off by default.

The icon follows the selected device's Core Audio mute state. It cannot read Zoom or Teams' private in-app mute state.

The unit tests cover state-to-icon and accessibility mapping. They do not exercise microphone hardware.

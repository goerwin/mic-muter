# Mic Muter

A menu-bar-only macOS app for toggling the selected microphone with a button or global shortcut.

## Requirements

- macOS 14 or later
- Xcode with Swift and `swift-format`

## Commands

- `make build` builds the app with Xcode.
- `make test` runs unit tests for mute state presentation and accessibility labels.
- `make lint` checks Swift sources with `swift-format`.
- `make install` builds a Release app and installs or replaces `/Applications/Mic Muter.app`. macOS may request an administrator password.

The shortcut starts unassigned. Choose one in the app's shortcut recorder. Launch at Login is off by default.

The icon follows the selected device's Core Audio mute state. It cannot read Zoom or Teams' private in-app mute state.

The unit tests cover state-to-icon and accessibility mapping. They do not exercise microphone hardware.

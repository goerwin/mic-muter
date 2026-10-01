# macOS smoke tests

Run with a spare microphone and no active call. Record the input levels before testing and restore them afterward.

- Left-click the status item and use the global shortcut. Confirm mute/unmute on the selected device and that the icon follows the result.
- Right-click to open options. Click outside to dismiss, and reopen using the keyboard/VoiceOver.
- Select System Default, then switch the default microphone in Sound settings. Confirm the app follows it.
- Select a specific microphone, disconnect it, and reconnect it. Confirm the unavailable placeholder and restored selection.
- With a channel-only volume device, change each input channel externally. Confirm the icon and fallback state update.
- Mute using the volume fallback, quit, and reopen. Confirm unmute restores the previous levels, including distinct channel values.
- Enable the HUD. Toggle repeatedly and while in a full-screen Space. Confirm the overlay does not steal focus and disappears normally.
- Change Launch at Login in System Settings, then reopen options. Confirm the checkbox matches. If approval is required, confirm the message and settings button work.
- Use VoiceOver to read status, device selection, errors, and settings.

Audio read/write failures, recovery retries, and listener replacement are covered with simulated devices in automated tests. Do not restart the system audio service during a call to test failure paths.

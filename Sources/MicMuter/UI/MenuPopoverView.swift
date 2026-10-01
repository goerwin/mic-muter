import KeyboardShortcuts
import SwiftUI

struct MenuPopoverView: View {
    @Bindable var model: MicMuterModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            muteControl
            inputDevicePicker
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                shortcutRow
                launchAtLoginRow
                showHUDOnToggleRow
            }
            HStack {
                Text("Mic Muter \(appVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Quit", action: model.terminate)
                    .keyboardShortcut("q", modifiers: .command)
            }
        }
        .padding(16)
        .frame(width: 280)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var muteControl: some View {
        VStack(spacing: 10) {
            Button(action: model.toggleMute) {
                Image(systemName: model.status.menuBarSymbol)
            }
            .buttonStyle(
                CircularMuteButtonStyle(
                    fill: muteButtonFill,
                    symbol: muteButtonSymbol,
                    isEnabled: model.canToggleSelectedDevice
                )
            )
            .disabled(!model.canToggleSelectedDevice)
            .accessibilityLabel(model.status.title)
            .accessibilityHint(toggleAccessibilityHint)

            Text(model.status.title)
                .font(.headline)

            if model.status == .inputSilent && model.isInputLevelZeroWithoutSavedValue {
                Text("Raise the input level in Sound settings to send audio.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let controlUnavailableMessage = model.controlUnavailableMessage {
                Text(controlUnavailableMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let errorMessage = model.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .padding(.bottom, 2)
    }

    private var muteButtonFill: Color {
        model.status == .unmuted ? .accentColor : Color.primary.opacity(0.08)
    }

    private var muteButtonSymbol: Color {
        model.status == .unmuted ? .white : .primary
    }

    private var inputDevicePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Microphone")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Microphone", selection: selectedDeviceBinding) {
                Text(defaultInputTitle)
                    .tag(nil as String?)

                Divider()

                if model.isSelectedDeviceDisconnected {
                    Text("\(model.selectedInputName) (Unavailable)")
                        .tag(model.selectedDeviceUID)
                        .disabled(true)
                }

                ForEach(model.devices) { device in
                    Text(device.name)
                        .tag(Optional(device.uid))
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity)
            .accessibilityValue(model.selectedInputName)
        }
    }

    private var shortcutRow: some View {
        HStack {
            Text("Shortcut")
            Spacer()
            KeyboardShortcuts.Recorder("Record shortcut", name: .toggleMicrophone)
                .labelsHidden()
                .controlSize(.small)
                .accessibilityLabel("Record global mute shortcut")
        }
    }

    private var launchAtLoginRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(
                "Launch at Login",
                isOn: Binding(
                    get: { model.launchAtLoginEnabled },
                    set: { model.setLaunchAtLogin($0) }
                )
            )
            .toggleStyle(.checkbox)

            if let launchAtLoginError = model.launchAtLoginError {
                Text(launchAtLoginError)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var showHUDOnToggleRow: some View {
        Toggle(
            "Show HUD on Toggle",
            isOn: Binding(
                get: { model.showHUDOnToggle },
                set: { model.setShowHUDOnToggle($0) }
            )
        )
        .toggleStyle(.checkbox)
        .accessibilityHint("Displays a brief overlay confirming the new microphone state")
    }

    private var selectedDeviceBinding: Binding<String?> {
        Binding(
            get: { model.selectedDeviceUID },
            set: { uid in
                guard let uid else {
                    model.selectDefaultInput()
                    return
                }
                guard let device = model.devices.first(where: { $0.uid == uid }) else { return }
                model.select(device)
            }
        )
    }

    private var defaultInputTitle: String {
        let name = model.currentDefaultDeviceName
        return name == "No input device" ? "System Default" : "System Default (\(name))"
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var toggleAccessibilityHint: String {
        switch model.status {
        case .muted:
            "Unmute the selected input device"
        case .unmuted, .unknown:
            "Mute the selected input device"
        case .inputSilent:
            "The input level is zero and cannot be restored by Mic Muter"
        case .unsupported:
            "This input device does not provide a writable mute control"
        case .disconnected:
            "Reconnect the selected input device to change its mute state"
        }
    }
}

private struct CircularMuteButtonStyle: ButtonStyle {
    var fill: Color
    var symbol: Color
    var isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 28, weight: .medium))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(symbol)
            .frame(width: 72, height: 72)
            .background {
                Circle()
                    .fill(fill)
            }
            .overlay {
                Circle()
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .opacity(isEnabled ? 1 : 0.42)
            .contentShape(Circle())
    }
}

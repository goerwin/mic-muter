import KeyboardShortcuts
import SwiftUI

struct MenuBarStatusItem: View {
    let status: MicStatus

    var body: some View {
        Image(systemName: status.menuBarSymbol)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(status.menuBarTint)
            .accessibilityLabel("Mic Muter. \(status.accessibilityDescription)")
            .help("Mic Muter: \(status.title)")
    }
}

struct MenuPopoverView: View {
    @Bindable var model: MicMuterModel
    @State private var showingAbout = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            muteControl
            inputDevicePicker
            Divider()
            shortcutRow
            launchAtLoginRow
            DisclosureGroup("About", isExpanded: $showingAbout) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Mic Muter")
                    Text("Version \(appVersion)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            }
            HStack {
                Spacer()
                Button("Quit", systemImage: "power", action: model.terminate)
                    .keyboardShortcut("q", modifiers: .command)
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    private var muteControl: some View {
        VStack(spacing: 8) {
            Button(action: model.toggleMute) {
                Image(systemName: model.status.menuBarSymbol)
                    .font(.system(size: 48, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 92, height: 72)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(model.status.menuBarTint)
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
    }

    private var inputDevicePicker: some View {
        LabeledContent("Input device") {
            Picker("Input device", selection: selectedDeviceBinding) {
                Text(defaultInputTitle)
                    .tag(nil as String?)

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
            .accessibilityValue(model.selectedInputName)
        }
    }

    private var shortcutRow: some View {
        LabeledContent("Keyboard shortcut") {
            KeyboardShortcuts.Recorder("Record shortcut", name: .toggleMicrophone)
                .labelsHidden()
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

            if let launchAtLoginError = model.launchAtLoginError {
                Text(launchAtLoginError)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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
        return name == "No input device" ? "Default Input" : "Default Input (\(name))"
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

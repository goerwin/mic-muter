import AppKit
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
        mainContent
            .padding(16)
            .frame(width: 338)
            .background(.regularMaterial)
    }

    private var mainContent: some View {
        VStack(spacing: 14) {
            header
            statusCard
            devicePicker
            shortcutRow
            Divider().padding(.vertical, 1)
            launchAtLoginRow
            aboutSection
            footer
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text("Mic Muter")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                Text("Microphone control")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Circle()
                .fill(statusIndicatorColor)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
        }
    }

    private var statusCard: some View {
        VStack(spacing: 10) {
            Button(action: model.toggleMute) {
                Image(systemName: model.status.menuBarSymbol)
                    .font(.system(size: 54, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(model.status.menuBarTint)
                    .frame(width: 132, height: 132)
                    .background(
                        model.status.menuBarTint.opacity(0.10),
                        in: Circle()
                    )
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!model.canToggleSelectedDevice)
            .accessibilityLabel(model.status.title)
            .accessibilityHint(toggleAccessibilityHint)

            VStack(spacing: 4) {
                Text(model.status.title)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                Text(model.status.accessibilityDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

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
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var devicePicker: some View {
        Menu {
            Button {
                model.selectDefaultInput()
            } label: {
                selectionLabel(
                    title: "Default Input",
                    subtitle: model.currentDefaultDeviceName,
                    isSelected: model.selectedDeviceUID == nil
                )
            }

            if model.isSelectedDeviceDisconnected {
                Divider()
                Label("\(model.selectedTargetTitle) · Unavailable", systemImage: "exclamationmark.circle")
                    .disabled(true)
            }

            if !model.devices.isEmpty {
                Divider()
                ForEach(model.devices) { device in
                    Button {
                        model.select(device)
                    } label: {
                        selectionLabel(
                            title: device.name,
                            subtitle: nil,
                            isSelected: model.selectedDeviceUID == device.uid
                        )
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "mic")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Input device")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(model.selectedTargetTitle)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    Text(model.selectedTargetSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("Input device")
        .accessibilityValue(model.selectedTargetTitle)
    }

    private var shortcutRow: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Keyboard shortcut")
                    .font(.subheadline.weight(.medium))
                Text(KeyboardShortcuts.Name.toggleMicrophone.shortcut == nil ? "Not set" : "Press to change")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 2)
            KeyboardShortcuts.Recorder("Record shortcut", name: .toggleMicrophone)
                .labelsHidden()
                .accessibilityLabel("Record global mute shortcut")
                .frame(maxWidth: 150)
        }
        .padding(.horizontal, 2)
    }

    private var launchAtLoginRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(
                isOn: Binding(
                    get: { model.launchAtLoginEnabled },
                    set: { model.setLaunchAtLogin($0) }
                )
            ) {
                Label("Launch at Login", systemImage: "arrow.turn.up.right")
                    .font(.subheadline.weight(.medium))
            }
            .toggleStyle(.switch)

            if let launchAtLoginError = model.launchAtLoginError {
                Text(launchAtLoginError)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 28)
            }
        }
    }

    private var aboutSection: some View {
        VStack(spacing: 0) {
            Divider()

            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    showingAbout.toggle()
                }
            } label: {
                HStack {
                    Label("About", systemImage: "info.circle")
                        .font(.subheadline)
                    Spacer()
                    Image(systemName: showingAbout ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
                .padding(.vertical, 9)
            }
            .buttonStyle(.plain)
            .accessibilityHint(showingAbout ? "Collapse About details" : "Show About details")

            if showingAbout {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mic Muter")
                        .font(.subheadline.weight(.semibold))
                    Text("Version \(appVersion)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("A simple control for your selected microphone.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 28)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button(action: model.terminate) {
                Label("Quit", systemImage: "power")
                    .font(.subheadline)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q", modifiers: .command)
        }
        .foregroundStyle(.secondary)
        .padding(.top, 1)
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

    private var statusIndicatorColor: Color {
        switch model.status {
        case .unmuted:
            .blue
        case .muted, .inputSilent:
            .primary
        case .unknown, .unsupported, .disconnected:
            .orange
        }
    }

    @ViewBuilder
    private func selectionLabel(title: String, subtitle: String?, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 12)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
            }
        }
    }
}

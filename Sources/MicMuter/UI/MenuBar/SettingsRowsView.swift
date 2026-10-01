import KeyboardShortcuts
import SwiftUI

struct SettingsRowsView: View {
    @Bindable var model: MicMuterModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Shortcut")
                Spacer()
                KeyboardShortcuts.Recorder("Record shortcut", name: .toggleMicrophone)
                    .labelsHidden()
                    .controlSize(.small)
                    .accessibilityLabel("Record global mute shortcut")
            }

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
    }
}

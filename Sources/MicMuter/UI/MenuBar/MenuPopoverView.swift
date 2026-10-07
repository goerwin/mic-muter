import SwiftUI

struct MenuPopoverView: View {
    @Bindable var model: MicMuterModel
    let onCheckForUpdates: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            MuteControlView(model: model)
            DevicePickerView(model: model)
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                Text("Preferences")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                SettingsRowsView(model: model)
            }
            Divider()
            VStack(spacing: 5) {
                if let repositoryURL = AppInfo.repositoryURL {
                    Link(destination: repositoryURL) {
                        Text("\(AppInfo.name) \(AppInfo.version)")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    Text("\(AppInfo.name) \(AppInfo.version)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                Button("Check for Updates…", action: onCheckForUpdates)
                    .buttonStyle(.link)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .center)

                HStack {
                    Spacer()
                    Button("Quit", action: model.terminate)
                        .keyboardShortcut("q", modifiers: .command)
                }
                .font(.caption)
            }
        }
        .padding(16)
        .frame(width: 280)
        .fixedSize(horizontal: false, vertical: true)
    }
}

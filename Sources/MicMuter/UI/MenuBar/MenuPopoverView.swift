import SwiftUI

struct MenuPopoverView: View {
    @Bindable var model: MicMuterModel
    let onCheckForUpdates: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            MuteControlView(model: model)
            DevicePickerView(model: model)
            Divider()
            SettingsRowsView(model: model)
            Button(action: onCheckForUpdates) {
                Label("Check for Updates…", systemImage: "arrow.down.circle")
            }
            .buttonStyle(.link)
            .font(.caption)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(AppInfo.name) \(AppInfo.version)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let repositoryURL = AppInfo.repositoryURL {
                        Link("GitHub", destination: repositoryURL)
                            .font(.caption)
                    }
                }
                Spacer()
                Button("Quit", action: model.terminate)
                    .keyboardShortcut("q", modifiers: .command)
            }
        }
        .padding(16)
        .frame(width: 280)
        .fixedSize(horizontal: false, vertical: true)
    }
}

import SwiftUI

struct MenuPopoverView: View {
    @Bindable var model: MicMuterModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            MuteControlView(model: model)
            DevicePickerView(model: model)
            Divider()
            SettingsRowsView(model: model)
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

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

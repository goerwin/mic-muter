import SwiftUI

struct AboutView: View {
    let onBack: () -> Void

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button(action: onBack) {
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(.plain)
                Spacer()
            }

            Image(systemName: "mic.fill")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(.blue)
                .frame(width: 68, height: 68)
                .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text("Mic Muter")
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                Text("Version \(version)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("A small, clear control for your selected microphone.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}

import SwiftUI

struct HUDOverlayView: View {
    let status: MicStatus
    let deviceName: String

    private static let iconSlot = CGSize(width: 64, height: 64)

    var body: some View {
        VStack(spacing: 12) {
            MicGlyphView(isSlashed: status.isSlashed)
                .foregroundStyle(status.isSlashed ? .white.opacity(0.55) : .white)
                .frame(width: Self.iconSlot.width, height: Self.iconSlot.height)

            VStack(spacing: 4) {
                Text(status.title)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)

                Text(deviceName)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.horizontal, 24)
        .frame(width: HUDOverlayController.panelSize.width, height: HUDOverlayController.panelSize.height)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.black.opacity(0.45))
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(status.accessibilityDescription). \(deviceName)")
    }
}

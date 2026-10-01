import SwiftUI

struct CircularMuteButtonStyle: ButtonStyle {
    var fill: Color
    var symbol: Color
    var isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(symbol)
            .frame(width: 72, height: 72)
            .background { Circle().fill(fill) }
            .overlay { Circle().strokeBorder(Color.primary.opacity(0.1), lineWidth: 1) }
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .opacity(isEnabled ? 1 : 0.42)
            .contentShape(Circle())
    }
}

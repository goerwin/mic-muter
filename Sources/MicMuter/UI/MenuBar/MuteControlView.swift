import SwiftUI

struct MuteControlView: View {
    @Bindable var model: MicMuterModel

    var body: some View {
        VStack(spacing: 10) {
            Button(action: model.toggleMute) {
                MicGlyphView(isSlashed: model.status.isSlashed)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(
                CircularMuteButtonStyle(
                    fill: model.status == .unmuted ? .accentColor : Color.primary.opacity(0.08),
                    symbol: model.status == .unmuted ? .white : .primary,
                    isEnabled: model.canToggleSelectedDevice
                )
            )
            .disabled(!model.canToggleSelectedDevice)
            .accessibilityLabel(model.status.title)
            .accessibilityHint(hint)

            Text(model.status.title)
                .font(.headline)

            if model.isRecoveryPending {
                Text("Click again to retry the microphone change.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if model.status == .inputSilent, model.isInputLevelZeroWithoutSavedValue {
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

    private var hint: String {
        if model.isRecoveryPending { return "Retry the pending microphone change" }
        return switch model.status {
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

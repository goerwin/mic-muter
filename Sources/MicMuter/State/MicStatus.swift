import SwiftUI

enum MicStatus: Equatable {
    case muted
    case unmuted
    case inputSilent
    case unknown
    case unsupported
    case disconnected

    var title: String {
        switch self {
        case .muted:
            "Microphone muted"
        case .unmuted:
            "Microphone on"
        case .inputSilent:
            "Input level is zero"
        case .unknown:
            "Mute state unknown"
        case .unsupported:
            "Mute unavailable"
        case .disconnected:
            "Microphone unavailable"
        }
    }

    var menuBarSymbol: String {
        switch self {
        case .muted, .inputSilent:
            "mic.slash.fill"
        case .unmuted, .unknown, .unsupported, .disconnected:
            "mic.fill"
        }
    }

    var menuBarTint: Color {
        switch self {
        case .unmuted:
            .blue
        case .muted, .inputSilent:
            .primary
        case .unknown, .unsupported, .disconnected:
            .secondary
        }
    }

    var actionTitle: String {
        switch self {
        case .muted:
            "Unmute microphone"
        case .unmuted:
            "Mute microphone"
        case .inputSilent:
            "Input level is zero"
        case .unknown:
            "Mute microphone"
        case .unsupported:
            "Mute unavailable"
        case .disconnected:
            "No microphone available"
        }
    }

    var accessibilityDescription: String {
        switch self {
        case .muted:
            "Muted"
        case .unmuted:
            "Unmuted"
        case .inputSilent:
            "Unmuted, but the input volume is zero"
        case .unknown:
            "The mute state cannot be confirmed"
        case .unsupported:
            "This microphone does not expose a writable mute or input volume control"
        case .disconnected:
            "The selected microphone is disconnected"
        }
    }

    var canToggle: Bool {
        switch self {
        case .muted, .unmuted, .unknown:
            true
        case .inputSilent, .unsupported, .disconnected:
            false
        }
    }
}

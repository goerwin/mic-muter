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
            "Microphone OFF"
        case .unmuted:
            "Microphone ON"
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

    var usesSlashSymbol: Bool {
        switch self {
        case .muted, .inputSilent:
            true
        case .unmuted, .unknown, .unsupported, .disconnected:
            false
        }
    }

    var tintsMenuBarIcon: Bool {
        self == .unmuted
    }

    var menuBarTint: Color {
        switch self {
        case .unmuted:
            .accentColor
        case .muted, .inputSilent:
            .primary
        case .unknown, .unsupported, .disconnected:
            .secondary
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

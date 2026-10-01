enum MicStatus: Equatable, CaseIterable {
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

    var isSlashed: Bool {
        self == .muted || self == .inputSilent
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

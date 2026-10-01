/// Pure mapping from the audio layer's device status to the
/// presentation-layer status. No I/O, fully unit-testable.
enum MicStatusMapper {
    static func map(_ audioStatus: AudioDeviceStatus, canControl: Bool) -> MicStatus {
        switch audioStatus {
        case .muted:
            .muted
        case .unmuted:
            .unmuted
        case .inputSilent:
            .inputSilent
        case .unknown:
            canControl ? .unknown : .unsupported
        }
    }
}

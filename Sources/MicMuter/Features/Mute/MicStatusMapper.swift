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

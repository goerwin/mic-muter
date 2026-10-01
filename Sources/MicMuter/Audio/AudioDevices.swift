import CoreAudio

struct AudioInputDevice: Identifiable, Hashable {
    let uid: String
    let name: String
    let objectID: AudioDeviceID
    let inputChannelCount: Int

    var id: String { uid }
}

enum AudioDeviceStatus: Equatable {
    case muted
    case unmuted
    case inputSilent
    case unknown
}

enum AudioDeviceError: LocalizedError {
    case unsupported
    case missingSavedInputLevel
    case coreAudio(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unsupported:
            "This device does not expose a writable mute or input volume control."
        case .missingSavedInputLevel:
            "The input level is already zero, and there is no saved level to restore."
        case .coreAudio(let status):
            "The audio device could not be changed (Core Audio error \(status))."
        }
    }
}

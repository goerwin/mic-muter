import CoreAudio
import Foundation

struct AudioInputDevice: Identifiable, Hashable {
    let uid: String
    let name: String
    let objectID: AudioDeviceID
    let inputChannelCount: Int

    var id: String { uid }
}

struct VolumeSnapshot: Codable, Equatable {
    let element: UInt32
    let value: Float
}

struct AudioInputVolumeProperty: Equatable {
    let element: UInt32
    let isWritable: Bool
}

struct AudioDeviceState: Equatable {
    let status: AudioDeviceStatus
    let canControl: Bool
    let hasSavedInputLevel: Bool
    let pendingMute: Bool?
}

struct VolumeFallbackState: Codable, Equatable {
    enum Phase: String, Codable {
        case muting
        case muted
        case restoring
    }

    let values: [VolumeSnapshot]
    var phase: Phase

    var pendingMute: Bool? {
        switch phase {
        case .muting: true
        case .muted: nil
        case .restoring: false
        }
    }
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
    case inputLevelWriteFailed
    case inputLevelReadFailed
    case coreAudio(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unsupported:
            "This device does not expose a writable mute or input volume control."
        case .missingSavedInputLevel:
            "The input level is already zero, and there is no saved level to restore."
        case .inputLevelWriteFailed:
            "The input level could not be changed or restored. Please try again."
        case .inputLevelReadFailed:
            "The input level could not be read. Please try again."
        case .coreAudio(let status):
            "The audio device could not be changed (Core Audio error \(status))."
        }
    }
}

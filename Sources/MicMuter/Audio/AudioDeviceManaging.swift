import Foundation

@MainActor
protocol AudioDeviceManaging: AnyObject {
    var inputDevices: [AudioInputDevice] { get }
    var defaultInputUID: String? { get }
    var onChange: (() -> Void)? { get set }

    func startMonitoring()
    func canControl(_ device: AudioInputDevice) -> Bool
    func status(for device: AudioInputDevice) -> AudioDeviceStatus
    func hasSavedInputLevel(for device: AudioInputDevice) -> Bool
    func setMuted(_ shouldMute: Bool, for device: AudioInputDevice) throws
}

extension CoreAudioDeviceManager: AudioDeviceManaging {}

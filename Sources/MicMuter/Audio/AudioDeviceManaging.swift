import Foundation

@MainActor
protocol AudioDeviceManaging: AnyObject {
    var inputDevices: [AudioInputDevice] { get }
    var defaultInputUID: String? { get }
    var onChange: (() -> Void)? { get set }

    func startMonitoring()
    func stopMonitoring()
    func state(for device: AudioInputDevice) -> AudioDeviceState
    func setMuted(_ shouldMute: Bool, for device: AudioInputDevice) throws
}

extension CoreAudioDeviceManager: AudioDeviceManaging {}

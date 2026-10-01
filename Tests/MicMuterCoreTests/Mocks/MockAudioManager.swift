import Foundation

@testable import MicMuterCore

@MainActor
final class MockAudioManager: AudioDeviceManaging {
    var inputDevices: [AudioInputDevice] = []
    var defaultInputUID: String?
    var onChange: (() -> Void)?
    var canControlValue = true
    var canControlHandler: ((AudioInputDevice) -> Bool)?
    var statusValue: AudioDeviceStatus = .unmuted
    var statusHandler: ((AudioInputDevice) -> AudioDeviceStatus)?
    var hasSavedLevel = false
    var setMutedHandler: ((Bool, AudioInputDevice) throws -> Void)?

    func startMonitoring() { onChange?() }

    func canControl(_ device: AudioInputDevice) -> Bool {
        canControlHandler?(device) ?? canControlValue
    }

    func status(for device: AudioInputDevice) -> AudioDeviceStatus {
        statusHandler?(device) ?? statusValue
    }

    func hasSavedInputLevel(for device: AudioInputDevice) -> Bool { hasSavedLevel }

    func setMuted(_ shouldMute: Bool, for device: AudioInputDevice) throws {
        try setMutedHandler?(shouldMute, device)
        statusValue = shouldMute ? .muted : .unmuted
        onChange?()
    }
}

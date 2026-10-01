#if DEBUG
    import Foundation

    @MainActor
    final class MockAudioManager: AudioDeviceManaging {
        var inputDevices: [AudioInputDevice] = []
        var defaultInputUID: String?
        var onChange: (() -> Void)?
        var canControlValue = true
        var statusValue: AudioDeviceStatus = .unmuted
        var hasSavedLevel = false
        var setMutedHandler: ((Bool, AudioInputDevice) throws -> Void)?

        func startMonitoring() { onChange?() }

        func canControl(_ device: AudioInputDevice) -> Bool { canControlValue }

        func status(for device: AudioInputDevice) -> AudioDeviceStatus { statusValue }

        func hasSavedInputLevel(for device: AudioInputDevice) -> Bool { hasSavedLevel }

        func setMuted(_ shouldMute: Bool, for device: AudioInputDevice) throws {
            try setMutedHandler?(shouldMute, device)
            statusValue = shouldMute ? .muted : .unmuted
            onChange?()
        }
    }
#endif

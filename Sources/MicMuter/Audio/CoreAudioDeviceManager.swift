import CoreAudio
import Foundation

@MainActor
final class CoreAudioDeviceManager {
    // MARK: - Types

    struct ListenerRegistration {
        let objectID: AudioObjectID
        let address: AudioObjectPropertyAddress
        let block: AudioObjectPropertyListenerBlock
    }

    // MARK: - State

    private(set) var inputDevices: [AudioInputDevice] = []
    private(set) var defaultInputUID: String?
    var onChange: (() -> Void)?

    // Shared with CoreAudioDeviceManager's focused extensions in sibling files.
    let systemObject = AudioObjectID(kAudioObjectSystemObject)
    var listeners: [String: ListenerRegistration] = [:]
    private let volumeStore: any VolumeStoring
    private let propertyAccess: any AudioDevicePropertyAccess

    init(volumeStore: any VolumeStoring, propertyAccess: any AudioDevicePropertyAccess) {
        self.volumeStore = volumeStore
        self.propertyAccess = propertyAccess
    }

    // MARK: - Monitoring

    func startMonitoring() {
        addListener(
            key: "system.devices",
            objectID: systemObject,
            address: audioPropertyAddress(kAudioHardwarePropertyDevices)
        )
        addListener(
            key: "system.defaultInput",
            objectID: systemObject,
            address: audioPropertyAddress(kAudioHardwarePropertyDefaultInputDevice)
        )
        refresh()
    }

    func refresh() {
        let newDevices = enumerateInputDevices()
        let newUIDs = Set(newDevices.map(\.uid))
        let oldUIDs = Set(inputDevices.map(\.uid))

        for device in inputDevices where !newUIDs.contains(device.uid) {
            removeDeviceListeners(for: device)
        }
        for device in newDevices where !oldUIDs.contains(device.uid) {
            addListener(
                key: "device.\(device.uid).mute",
                objectID: device.objectID,
                address: audioPropertyAddress(
                    kAudioDevicePropertyMute,
                    scope: kAudioDevicePropertyScopeInput
                )
            )
            addListener(
                key: "device.\(device.uid).volume",
                objectID: device.objectID,
                address: audioPropertyAddress(
                    kAudioDevicePropertyVolumeScalar,
                    scope: kAudioDevicePropertyScopeInput
                )
            )
        }

        inputDevices = newDevices
        defaultInputUID = defaultInputDeviceID().flatMap { id in
            newDevices.first(where: { $0.objectID == id })?.uid
        }
        reconcileStaleFallbackState()
        onChange?()
    }

    /// Clears fallback-mute flags the user resolved externally (e.g. raised
    /// the input level in System Settings). Kept out of `status(for:)` so
    /// queries stay side-effect free.
    private func reconcileStaleFallbackState() {
        for device in inputDevices {
            reconcileStaleFallbackState(for: device)
        }
    }

    func reconcileStaleFallbackState(for device: AudioInputDevice) {
        guard volumeStore.isFallbackMuteActive(forDeviceUID: device.uid),
            !volumeStore.isRestorePending(forDeviceUID: device.uid)
        else {
            return
        }

        let volumes = propertyAccess.volumeValues(for: device)
        let inputIsZero = !volumes.isEmpty && volumes.allSatisfy { $0.value <= 0.0001 }
        if !inputIsZero {
            volumeStore.clearSavedInputLevel(forDeviceUID: device.uid)
        }
    }

    // MARK: - Public API

    func canControl(_ device: AudioInputDevice) -> Bool {
        propertyAccess.canSetMute(for: device) || hasWritableInputVolumes(for: device)
    }

    func status(for device: AudioInputDevice) -> AudioDeviceStatus {
        let muteValue = propertyAccess.muteValue(for: device)
        let volumeValues = propertyAccess.volumeValues(for: device)
        let inputIsZero = !volumeValues.isEmpty && volumeValues.allSatisfy { $0.value <= 0.0001 }
        if volumeStore.isRestorePending(forDeviceUID: device.uid) {
            return .unknown
        }

        if volumeStore.isFallbackMuteActive(forDeviceUID: device.uid), inputIsZero {
            return .muted
        }

        if muteValue == true {
            return .muted
        }
        if muteValue == false {
            return inputIsZero ? .inputSilent : .unmuted
        }
        if !volumeValues.isEmpty {
            return inputIsZero ? .inputSilent : .unmuted
        }
        return .unknown
    }

    func hasSavedInputLevel(for device: AudioInputDevice) -> Bool {
        volumeStore.savedInputLevel(forDeviceUID: device.uid) != nil
    }

    func setMuted(_ shouldMute: Bool, for device: AudioInputDevice) throws {
        if volumeStore.isRestorePending(forDeviceUID: device.uid) {
            try restoreInputLevel(for: device)
            if !shouldMute { return }
        }

        if shouldMute {
            if propertyAccess.canSetMute(for: device), propertyAccess.setMute(true, for: device) {
                volumeStore.setFallbackMuteActive(false, forDeviceUID: device.uid)
                onChange?()
                return
            }
            try muteByZeroingInput(for: device)
            return
        }

        if volumeStore.isFallbackMuteActive(forDeviceUID: device.uid) {
            try restoreInputLevel(for: device)
            return
        }

        if propertyAccess.canSetMute(for: device), propertyAccess.setMute(false, for: device) {
            onChange?()
            return
        }

        if propertyAccess.volumeValues(for: device).first?.value == 0 {
            if volumeStore.savedInputLevel(forDeviceUID: device.uid) != nil {
                try restoreInputLevel(for: device)
            } else {
                throw AudioDeviceError.missingSavedInputLevel
            }
            return
        }

        throw AudioDeviceError.unsupported
    }

    // MARK: - Mute via volume fallback

    private func hasWritableInputVolumes(for device: AudioInputDevice) -> Bool {
        let controls = propertyAccess.volumeProperties(for: device)
        return !controls.isEmpty && controls.allSatisfy(\.isWritable)
    }

    private func muteByZeroingInput(for device: AudioInputDevice) throws {
        let controls = propertyAccess.volumeProperties(for: device)
        let currentValues = propertyAccess.volumeValues(for: device)
        guard !controls.isEmpty,
            currentValues.map(\.element) == controls.map(\.element),
            controls.allSatisfy(\.isWritable)
        else {
            throw AudioDeviceError.unsupported
        }

        volumeStore.saveInputLevel(currentValues, forDeviceUID: device.uid)
        volumeStore.setFallbackMuteActive(true, forDeviceUID: device.uid)
        volumeStore.setRestorePending(false, forDeviceUID: device.uid)

        let zeroValues = currentValues.map { VolumeSnapshot(element: $0.element, value: 0) }
        guard propertyAccess.writeVolumeValues(zeroValues, for: device) else {
            if propertyAccess.writeVolumeValues(currentValues, for: device) {
                volumeStore.clearSavedInputLevel(forDeviceUID: device.uid)
            } else {
                volumeStore.setRestorePending(true, forDeviceUID: device.uid)
            }
            throw AudioDeviceError.inputLevelWriteFailed
        }
        onChange?()
    }

    private func restoreInputLevel(for device: AudioInputDevice) throws {
        guard let savedVolume = volumeStore.savedInputLevel(forDeviceUID: device.uid) else {
            throw AudioDeviceError.missingSavedInputLevel
        }
        guard propertyAccess.writeVolumeValues(savedVolume, for: device) else {
            volumeStore.setRestorePending(true, forDeviceUID: device.uid)
            throw AudioDeviceError.inputLevelWriteFailed
        }
        volumeStore.clearSavedInputLevel(forDeviceUID: device.uid)
        onChange?()
    }
}

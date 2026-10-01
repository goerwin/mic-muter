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
    let volumeStore: any VolumeStoring
    var listeners: [String: ListenerRegistration] = [:]

    init(volumeStore: any VolumeStoring) {
        self.volumeStore = volumeStore
    }

    // MARK: - Monitoring

    func startMonitoring() {
        addListener(
            key: "system.devices",
            objectID: systemObject,
            address: propertyAddress(kAudioHardwarePropertyDevices)
        )
        addListener(
            key: "system.defaultInput",
            objectID: systemObject,
            address: propertyAddress(kAudioHardwarePropertyDefaultInputDevice)
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
                address: propertyAddress(
                    kAudioDevicePropertyMute,
                    scope: kAudioDevicePropertyScopeInput
                )
            )
            addListener(
                key: "device.\(device.uid).volume",
                objectID: device.objectID,
                address: propertyAddress(
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
            guard volumeStore.isFallbackMuteActive(forDeviceUID: device.uid) else { continue }
            let volumes = readVolumeValues(for: device)
            let inputIsZero = !volumes.isEmpty && volumes.allSatisfy { $0.value <= 0.0001 }
            if !inputIsZero {
                volumeStore.clearSavedInputLevel(forDeviceUID: device.uid)
            }
        }
    }

    // MARK: - Public API

    func canControl(_ device: AudioInputDevice) -> Bool {
        canSetMute(device.objectID) || hasWritableInputVolumes(for: device)
    }

    func status(for device: AudioInputDevice) -> AudioDeviceStatus {
        let muteValue = readMuteValue(device.objectID)
        let volumeValues = readVolumeValues(for: device)
        let inputIsZero = !volumeValues.isEmpty && volumeValues.allSatisfy { $0.value <= 0.0001 }
        let fallbackMuteIsActive = volumeStore.isFallbackMuteActive(forDeviceUID: device.uid)

        if fallbackMuteIsActive, inputIsZero {
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
        if shouldMute {
            if canSetMute(device.objectID), setMuteValue(true, for: device.objectID) == noErr {
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

        if canSetMute(device.objectID), setMuteValue(false, for: device.objectID) == noErr {
            onChange?()
            return
        }

        if readInputVolume(for: device) == 0 {
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

    private func muteByZeroingInput(for device: AudioInputDevice) throws {
        let addresses = volumeAddresses(for: device)
        let currentValues = readVolumeValues(for: device)
        let writableElements = Set(writableVolumeAddresses(for: device).map(\.mElement))
        guard !addresses.isEmpty,
            currentValues.count == addresses.count,
            addresses.allSatisfy({ writableElements.contains($0.mElement) })
        else {
            throw AudioDeviceError.unsupported
        }

        volumeStore.saveInputLevel(currentValues, forDeviceUID: device.uid)
        volumeStore.setFallbackMuteActive(true, forDeviceUID: device.uid)

        let zeroValues = currentValues.map { VolumeSnapshot(element: $0.element, value: 0) }
        guard writeVolumeValues(zeroValues, for: device) else {
            _ = writeVolumeValues(currentValues, for: device)
            volumeStore.clearSavedInputLevel(forDeviceUID: device.uid)
            throw AudioDeviceError.unsupported
        }
        onChange?()
    }

    private func restoreInputLevel(for device: AudioInputDevice) throws {
        guard let savedVolume = volumeStore.savedInputLevel(forDeviceUID: device.uid) else {
            throw AudioDeviceError.missingSavedInputLevel
        }
        guard writeVolumeValues(savedVolume, for: device) else {
            throw AudioDeviceError.unsupported
        }
        volumeStore.clearSavedInputLevel(forDeviceUID: device.uid)
        onChange?()
    }
}

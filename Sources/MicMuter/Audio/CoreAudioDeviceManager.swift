import CoreAudio
import Foundation

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

@MainActor
final class CoreAudioDeviceManager {
    // MARK: - Types

    private struct ListenerRegistration {
        let objectID: AudioObjectID
        let address: AudioObjectPropertyAddress
        let block: AudioObjectPropertyListenerBlock
    }

    private struct VolumeValue: Codable {
        let element: UInt32
        let value: Float
    }

    private struct SavedVolume: Codable {
        let values: [VolumeValue]
    }

    // MARK: - State

    private(set) var inputDevices: [AudioInputDevice] = []
    private(set) var defaultInputUID: String?
    var onChange: (() -> Void)?

    private let systemObject = AudioObjectID(kAudioObjectSystemObject)
    private let savedVolumePrefix = "savedInputVolume."
    private let fallbackMutePrefix = "mutedByInputVolume."
    private var listeners: [String: ListenerRegistration] = [:]

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
        onChange?()
    }

    // MARK: - Public API

    func canControl(_ device: AudioInputDevice) -> Bool {
        canSetMute(device.objectID) || hasWritableInputVolumes(for: device)
    }

    func status(for device: AudioInputDevice) -> AudioDeviceStatus {
        let muteValue = readMuteValue(device.objectID)
        let volumeValues = readVolumeValues(for: device)
        let inputIsZero = !volumeValues.isEmpty && volumeValues.allSatisfy { $0.value <= 0.0001 }
        let fallbackMuteIsActive = UserDefaults.standard.bool(forKey: fallbackMutePrefix + device.uid)

        if fallbackMuteIsActive, inputIsZero {
            return .muted
        }
        if fallbackMuteIsActive, !inputIsZero {
            clearSavedInputLevel(for: device)
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
        savedVolume(for: device) != nil
    }

    func setMuted(_ shouldMute: Bool, for device: AudioInputDevice) throws {
        if shouldMute {
            if canSetMute(device.objectID), setMuteValue(true, for: device.objectID) == noErr {
                UserDefaults.standard.set(false, forKey: fallbackMutePrefix + device.uid)
                onChange?()
                return
            }
            try muteByZeroingInput(for: device)
            return
        }

        if UserDefaults.standard.bool(forKey: fallbackMutePrefix + device.uid) {
            try restoreInputLevel(for: device)
            return
        }

        if canSetMute(device.objectID), setMuteValue(false, for: device.objectID) == noErr {
            onChange?()
            return
        }

        if readInputVolume(for: device) == 0 {
            if savedVolume(for: device) != nil {
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

        saveInputLevel(currentValues, for: device)
        UserDefaults.standard.set(true, forKey: fallbackMutePrefix + device.uid)

        let zeroValues = currentValues.map { VolumeValue(element: $0.element, value: 0) }
        guard writeVolumeValues(zeroValues, for: device) else {
            _ = writeVolumeValues(currentValues, for: device)
            clearSavedInputLevel(for: device)
            throw AudioDeviceError.unsupported
        }
        onChange?()
    }

    private func restoreInputLevel(for device: AudioInputDevice) throws {
        guard let savedVolume = savedVolume(for: device) else {
            throw AudioDeviceError.missingSavedInputLevel
        }
        guard writeVolumeValues(savedVolume.values, for: device) else {
            throw AudioDeviceError.unsupported
        }
        clearSavedInputLevel(for: device)
        onChange?()
    }

    // MARK: - Discovery

    private func enumerateInputDevices() -> [AudioInputDevice] {
        var address = propertyAddress(kAudioHardwarePropertyDevices)
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(systemObject, &address, 0, nil, &dataSize) == noErr else {
            return []
        }

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.stride
        guard count > 0 else { return [] }
        var objectIDs = [AudioDeviceID](repeating: 0, count: count)
        let status = objectIDs.withUnsafeMutableBytes { bytes in
            guard let baseAddress = bytes.baseAddress else {
                return kAudioHardwareBadPropertySizeError
            }
            return AudioObjectGetPropertyData(
                systemObject,
                &address,
                0,
                nil,
                &dataSize,
                baseAddress
            )
        }
        guard status == noErr else { return [] }

        return objectIDs.compactMap { objectID in
            let channelCount = inputChannelCount(for: objectID)
            guard channelCount > 0,
                let uid = stringProperty(objectID, selector: kAudioDevicePropertyDeviceUID)
            else {
                return nil
            }
            let name = stringProperty(objectID, selector: kAudioObjectPropertyName) ?? "Input device"
            return AudioInputDevice(uid: uid, name: name, objectID: objectID, inputChannelCount: channelCount)
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func inputChannelCount(for objectID: AudioObjectID) -> Int {
        var address = propertyAddress(
            kAudioDevicePropertyStreamConfiguration,
            scope: kAudioDevicePropertyScopeInput
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(objectID, &address, 0, nil, &dataSize) == noErr,
            dataSize > 0
        else {
            return 0
        }

        let rawList = UnsafeMutableRawPointer.allocate(
            byteCount: Int(dataSize),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { rawList.deallocate() }
        let bufferList = rawList.bindMemory(to: AudioBufferList.self, capacity: 1)
        guard AudioObjectGetPropertyData(objectID, &address, 0, nil, &dataSize, bufferList) == noErr else {
            return 0
        }
        return UnsafeMutableAudioBufferListPointer(bufferList)
            .reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    private func defaultInputDeviceID() -> AudioDeviceID? {
        var address = propertyAddress(kAudioHardwarePropertyDefaultInputDevice)
        var objectID = AudioDeviceID(kAudioObjectUnknown)
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(systemObject, &address, 0, nil, &dataSize, &objectID)
        guard status == noErr, objectID != AudioDeviceID(kAudioObjectUnknown) else { return nil }
        return objectID
    }

    // MARK: - CoreAudio helpers

    private func stringProperty(_ objectID: AudioObjectID, selector: AudioObjectPropertySelector) -> String? {
        var address = propertyAddress(selector)
        var value: Unmanaged<CFString>?
        var dataSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(objectID, &address, 0, nil, &dataSize, &value)
        guard status == noErr, let value else { return nil }
        return value.takeRetainedValue() as String
    }

    private func readMuteValue(_ objectID: AudioObjectID) -> Bool? {
        var address = propertyAddress(
            kAudioDevicePropertyMute,
            scope: kAudioDevicePropertyScopeInput
        )
        guard AudioObjectHasProperty(objectID, &address) else { return nil }
        var value: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(objectID, &address, 0, nil, &dataSize, &value)
        guard status == noErr else { return nil }
        return value != 0
    }

    private func readVolumeValues(for device: AudioInputDevice) -> [VolumeValue] {
        let addresses = volumeAddresses(for: device)
        let values = addresses.compactMap { address -> VolumeValue? in
            var propertyAddress = address
            var value: Float = 0
            var dataSize = UInt32(MemoryLayout<Float>.size)
            guard
                AudioObjectGetPropertyData(
                    device.objectID,
                    &propertyAddress,
                    0,
                    nil,
                    &dataSize,
                    &value
                ) == noErr
            else {
                return nil
            }
            return VolumeValue(element: address.mElement, value: value)
        }
        return values
    }

    private func readInputVolume(for device: AudioInputDevice) -> Float? {
        readVolumeValues(for: device).first?.value
    }

    private func volumeAddresses(for device: AudioInputDevice) -> [AudioObjectPropertyAddress] {
        let master = propertyAddress(
            kAudioDevicePropertyVolumeScalar,
            scope: kAudioDevicePropertyScopeInput,
            element: kAudioObjectPropertyElementMain
        )
        if AudioObjectHasProperty(device.objectID, withUnsafePointer(to: master, { $0 })) {
            var address = master
            var dataSize = UInt32(MemoryLayout<Float>.size)
            var value: Float = 0
            if AudioObjectGetPropertyData(device.objectID, &address, 0, nil, &dataSize, &value) == noErr {
                return [master]
            }
        }

        return (1...max(1, device.inputChannelCount)).map { channel in
            propertyAddress(
                kAudioDevicePropertyVolumeScalar,
                scope: kAudioDevicePropertyScopeInput,
                element: AudioObjectPropertyElement(channel)
            )
        }.filter { address in
            AudioObjectHasProperty(device.objectID, withUnsafePointer(to: address, { $0 }))
        }
    }

    private func writableVolumeAddresses(for device: AudioInputDevice) -> [AudioObjectPropertyAddress] {
        volumeAddresses(for: device).filter { address in
            var mutableAddress = address
            var isSettable = DarwinBoolean(false)
            return AudioObjectIsPropertySettable(device.objectID, &mutableAddress, &isSettable) == noErr
                && isSettable.boolValue
        }
    }

    private func hasWritableInputVolumes(for device: AudioInputDevice) -> Bool {
        let addresses = volumeAddresses(for: device)
        return !addresses.isEmpty && writableVolumeAddresses(for: device).count == addresses.count
    }

    private func canSetMute(_ objectID: AudioObjectID) -> Bool {
        var address = propertyAddress(kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeInput)
        var isSettable = DarwinBoolean(false)
        return AudioObjectHasProperty(objectID, &address)
            && AudioObjectIsPropertySettable(objectID, &address, &isSettable) == noErr
            && isSettable.boolValue
    }

    private func setMuteValue(_ muted: Bool, for objectID: AudioObjectID) -> OSStatus {
        var address = propertyAddress(kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeInput)
        var value: UInt32 = muted ? 1 : 0
        let dataSize = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectSetPropertyData(objectID, &address, 0, nil, dataSize, &value)
    }

    private func writeVolumeValues(_ values: [VolumeValue], for device: AudioInputDevice) -> Bool {
        guard !values.isEmpty else { return false }
        var didWriteAll = true
        for volume in values {
            var address = propertyAddress(
                kAudioDevicePropertyVolumeScalar,
                scope: kAudioDevicePropertyScopeInput,
                element: AudioObjectPropertyElement(volume.element)
            )
            var value = volume.value
            let status = AudioObjectSetPropertyData(
                device.objectID,
                &address,
                0,
                nil,
                UInt32(MemoryLayout<Float>.size),
                &value
            )
            if status != noErr { didWriteAll = false }
        }
        return didWriteAll
    }

    // MARK: - Persistence

    private func saveInputLevel(_ values: [VolumeValue], for device: AudioInputDevice) {
        let saved = SavedVolume(values: values)
        guard let data = try? JSONEncoder().encode(saved) else { return }
        UserDefaults.standard.set(data, forKey: savedVolumePrefix + device.uid)
    }

    private func savedVolume(for device: AudioInputDevice) -> SavedVolume? {
        guard let data = UserDefaults.standard.data(forKey: savedVolumePrefix + device.uid) else { return nil }
        return try? JSONDecoder().decode(SavedVolume.self, from: data)
    }

    private func clearSavedInputLevel(for device: AudioInputDevice) {
        UserDefaults.standard.removeObject(forKey: savedVolumePrefix + device.uid)
        UserDefaults.standard.removeObject(forKey: fallbackMutePrefix + device.uid)
    }

    // MARK: - Listeners

    private func removeDeviceListeners(for device: AudioInputDevice) {
        removeListener(key: "device.\(device.uid).mute")
        removeListener(key: "device.\(device.uid).volume")
    }

    private func addListener(
        key: String,
        objectID: AudioObjectID,
        address: AudioObjectPropertyAddress
    ) {
        guard listeners[key] == nil else { return }
        var mutableAddress = address
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
        let status = AudioObjectAddPropertyListenerBlock(objectID, &mutableAddress, .main, block)
        guard status == noErr else { return }
        listeners[key] = ListenerRegistration(objectID: objectID, address: address, block: block)
    }

    private func removeListener(key: String) {
        guard let listener = listeners.removeValue(forKey: key) else { return }
        var address = listener.address
        AudioObjectRemovePropertyListenerBlock(listener.objectID, &address, .main, listener.block)
    }

    private func propertyAddress(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
    }
}

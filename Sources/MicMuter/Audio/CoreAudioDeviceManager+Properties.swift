import CoreAudio

extension CoreAudioDeviceManager {
    func stringProperty(_ objectID: AudioObjectID, selector: AudioObjectPropertySelector) -> String? {
        var address = propertyAddress(selector)
        var value: Unmanaged<CFString>?
        var dataSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(objectID, &address, 0, nil, &dataSize, &value)
        guard status == noErr, let value else { return nil }
        return value.takeRetainedValue() as String
    }

    func readMuteValue(_ objectID: AudioObjectID) -> Bool? {
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

    func readVolumeValues(for device: AudioInputDevice) -> [VolumeSnapshot] {
        let addresses = volumeAddresses(for: device)
        let values = addresses.compactMap { address -> VolumeSnapshot? in
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
            return VolumeSnapshot(element: address.mElement, value: value)
        }
        return values
    }

    func readInputVolume(for device: AudioInputDevice) -> Float? {
        readVolumeValues(for: device).first?.value
    }

    func volumeAddresses(for device: AudioInputDevice) -> [AudioObjectPropertyAddress] {
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

    func writableVolumeAddresses(for device: AudioInputDevice) -> [AudioObjectPropertyAddress] {
        volumeAddresses(for: device).filter { address in
            var mutableAddress = address
            var isSettable = DarwinBoolean(false)
            return AudioObjectIsPropertySettable(device.objectID, &mutableAddress, &isSettable) == noErr
                && isSettable.boolValue
        }
    }

    func hasWritableInputVolumes(for device: AudioInputDevice) -> Bool {
        let addresses = volumeAddresses(for: device)
        return !addresses.isEmpty && writableVolumeAddresses(for: device).count == addresses.count
    }

    func canSetMute(_ objectID: AudioObjectID) -> Bool {
        var address = propertyAddress(kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeInput)
        var isSettable = DarwinBoolean(false)
        return AudioObjectHasProperty(objectID, &address)
            && AudioObjectIsPropertySettable(objectID, &address, &isSettable) == noErr
            && isSettable.boolValue
    }

    func setMuteValue(_ muted: Bool, for objectID: AudioObjectID) -> OSStatus {
        var address = propertyAddress(kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeInput)
        var value: UInt32 = muted ? 1 : 0
        let dataSize = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectSetPropertyData(objectID, &address, 0, nil, dataSize, &value)
    }

    func writeVolumeValues(_ values: [VolumeSnapshot], for device: AudioInputDevice) -> Bool {
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

    func propertyAddress(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
    }
}

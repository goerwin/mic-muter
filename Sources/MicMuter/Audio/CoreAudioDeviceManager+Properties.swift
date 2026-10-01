import CoreAudio

@MainActor
protocol AudioDevicePropertyAccess: AnyObject {
    func muteValue(for device: AudioInputDevice) -> Bool?
    func canSetMute(for device: AudioInputDevice) -> Bool
    func setMute(_ muted: Bool, for device: AudioInputDevice) -> Bool
    func volumeProperties(for device: AudioInputDevice) -> [AudioInputVolumeProperty]
    // nil is a failed read; an empty array means no volume controls.
    func volumeValues(for device: AudioInputDevice) -> [VolumeSnapshot]?
    func writeVolumeValues(_ values: [VolumeSnapshot], for device: AudioInputDevice) -> Bool
}

@MainActor
final class CoreAudioDevicePropertyAccess: AudioDevicePropertyAccess {
    func muteValue(for device: AudioInputDevice) -> Bool? {
        var address = audioPropertyAddress(
            kAudioDevicePropertyMute,
            scope: kAudioDevicePropertyScopeInput
        )
        guard AudioObjectHasProperty(device.objectID, &address) else { return nil }
        var value: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(device.objectID, &address, 0, nil, &dataSize, &value)
        guard status == noErr else { return nil }
        return value != 0
    }

    func canSetMute(for device: AudioInputDevice) -> Bool {
        var address = audioPropertyAddress(kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeInput)
        var isSettable = DarwinBoolean(false)
        return AudioObjectHasProperty(device.objectID, &address)
            && AudioObjectIsPropertySettable(device.objectID, &address, &isSettable) == noErr
            && isSettable.boolValue
    }

    func setMute(_ muted: Bool, for device: AudioInputDevice) -> Bool {
        var address = audioPropertyAddress(kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeInput)
        var value: UInt32 = muted ? 1 : 0
        let dataSize = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectSetPropertyData(device.objectID, &address, 0, nil, dataSize, &value) == noErr
    }

    func volumeProperties(for device: AudioInputDevice) -> [AudioInputVolumeProperty] {
        volumeAddresses(for: device).map { address in
            var mutableAddress = address
            var isSettable = DarwinBoolean(false)
            let isWritable =
                AudioObjectIsPropertySettable(
                    device.objectID,
                    &mutableAddress,
                    &isSettable
                ) == noErr && isSettable.boolValue
            return AudioInputVolumeProperty(element: address.mElement, isWritable: isWritable)
        }
    }

    func volumeValues(for device: AudioInputDevice) -> [VolumeSnapshot]? {
        var values: [VolumeSnapshot] = []
        for address in volumeAddresses(for: device) {
            var mutableAddress = address
            var value: Float = 0
            var dataSize = UInt32(MemoryLayout<Float>.size)
            guard AudioObjectGetPropertyData(device.objectID, &mutableAddress, 0, nil, &dataSize, &value) == noErr
            else {
                return nil
            }
            guard value.isFinite, (0...1).contains(value) else { return nil }
            values.append(VolumeSnapshot(element: address.mElement, value: value))
        }
        return values
    }

    func writeVolumeValues(_ values: [VolumeSnapshot], for device: AudioInputDevice) -> Bool {
        guard !values.isEmpty else { return false }
        var didWriteAll = true
        for volume in values {
            var address = audioPropertyAddress(
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

    private func volumeAddresses(for device: AudioInputDevice) -> [AudioObjectPropertyAddress] {
        let master = audioPropertyAddress(
            kAudioDevicePropertyVolumeScalar,
            scope: kAudioDevicePropertyScopeInput,
            element: kAudioObjectPropertyElementMain
        )
        if AudioObjectHasProperty(device.objectID, withUnsafePointer(to: master, { $0 })) {
            return [master]
        }

        return (1...max(1, device.inputChannelCount)).map { channel in
            audioPropertyAddress(
                kAudioDevicePropertyVolumeScalar,
                scope: kAudioDevicePropertyScopeInput,
                element: AudioObjectPropertyElement(channel)
            )
        }.filter { address in
            AudioObjectHasProperty(device.objectID, withUnsafePointer(to: address, { $0 }))
        }
    }
}

extension CoreAudioDeviceMonitor {
    func stringProperty(_ objectID: AudioObjectID, selector: AudioObjectPropertySelector) -> String? {
        var address = audioPropertyAddress(selector)
        var value: Unmanaged<CFString>?
        var dataSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(objectID, &address, 0, nil, &dataSize, &value)
        guard status == noErr, let value else { return nil }
        return value.takeRetainedValue() as String
    }
}

func audioPropertyAddress(
    _ selector: AudioObjectPropertySelector,
    scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
    element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
}

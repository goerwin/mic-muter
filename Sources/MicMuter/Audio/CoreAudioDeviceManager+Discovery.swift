import CoreAudio

enum AudioDeviceMonitoringError: Error {
    case deviceEnumeration(OSStatus)
    case defaultInput(OSStatus)
}

@MainActor
protocol AudioDeviceMonitoring: AnyObject {
    func enumerateInputDevices() throws -> [AudioInputDevice]
    func defaultInputDeviceID() throws -> AudioDeviceID?
    func addListener(
        objectID: AudioObjectID, address: AudioObjectPropertyAddress, block: @escaping AudioObjectPropertyListenerBlock
    ) -> OSStatus
    func removeListener(
        objectID: AudioObjectID, address: AudioObjectPropertyAddress, block: @escaping AudioObjectPropertyListenerBlock
    ) -> OSStatus
}

@MainActor
final class CoreAudioDeviceMonitor: AudioDeviceMonitoring {
    private let systemObject = AudioObjectID(kAudioObjectSystemObject)

    func enumerateInputDevices() throws -> [AudioInputDevice] {
        var address = audioPropertyAddress(kAudioHardwarePropertyDevices)
        var dataSize: UInt32 = 0
        let sizeStatus = AudioObjectGetPropertyDataSize(systemObject, &address, 0, nil, &dataSize)
        guard sizeStatus == noErr else {
            throw AudioDeviceMonitoringError.deviceEnumeration(sizeStatus)
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
        guard status == noErr else { throw AudioDeviceMonitoringError.deviceEnumeration(status) }

        return try objectIDs.compactMap { objectID in
            let channelCount = try inputChannelCount(for: objectID)
            guard channelCount > 0,
                let uid = try stringProperty(objectID, selector: kAudioDevicePropertyDeviceUID)
            else {
                return nil
            }
            let name = try stringProperty(objectID, selector: kAudioObjectPropertyName) ?? "Input device"
            return AudioInputDevice(uid: uid, name: name, objectID: objectID, inputChannelCount: channelCount)
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func inputChannelCount(for objectID: AudioObjectID) throws -> Int {
        var address = audioPropertyAddress(
            kAudioDevicePropertyStreamConfiguration,
            scope: kAudioDevicePropertyScopeInput
        )
        guard AudioObjectHasProperty(objectID, &address) else { return 0 }
        var dataSize: UInt32 = 0
        let sizeStatus = AudioObjectGetPropertyDataSize(objectID, &address, 0, nil, &dataSize)
        guard sizeStatus == noErr else {
            throw AudioDeviceMonitoringError.deviceEnumeration(sizeStatus)
        }
        guard dataSize > 0 else { return 0 }

        let rawList = UnsafeMutableRawPointer.allocate(
            byteCount: Int(dataSize),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { rawList.deallocate() }
        let bufferList = rawList.bindMemory(to: AudioBufferList.self, capacity: 1)
        let status = AudioObjectGetPropertyData(objectID, &address, 0, nil, &dataSize, bufferList)
        guard status == noErr else {
            throw AudioDeviceMonitoringError.deviceEnumeration(status)
        }
        return UnsafeMutableAudioBufferListPointer(bufferList)
            .reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    func defaultInputDeviceID() throws -> AudioDeviceID? {
        var address = audioPropertyAddress(kAudioHardwarePropertyDefaultInputDevice)
        var objectID = AudioDeviceID(kAudioObjectUnknown)
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(systemObject, &address, 0, nil, &dataSize, &objectID)
        guard status == noErr else { throw AudioDeviceMonitoringError.defaultInput(status) }
        guard objectID != AudioDeviceID(kAudioObjectUnknown) else { return nil }
        return objectID
    }

    private func stringProperty(_ objectID: AudioObjectID, selector: AudioObjectPropertySelector) throws -> String? {
        var address = audioPropertyAddress(selector)
        guard AudioObjectHasProperty(objectID, &address) else { return nil }
        var value: Unmanaged<CFString>?
        var dataSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(objectID, &address, 0, nil, &dataSize, &value)
        guard status == noErr else { throw AudioDeviceMonitoringError.deviceEnumeration(status) }
        guard let value else { return nil }
        return value.takeRetainedValue() as String
    }
}

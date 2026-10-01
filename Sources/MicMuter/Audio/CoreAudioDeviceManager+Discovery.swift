import CoreAudio

@MainActor
protocol AudioDeviceMonitoring: AnyObject {
    func enumerateInputDevices() -> [AudioInputDevice]
    func defaultInputDeviceID() -> AudioDeviceID?
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

    func enumerateInputDevices() -> [AudioInputDevice] {
        var address = audioPropertyAddress(kAudioHardwarePropertyDevices)
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

    func inputChannelCount(for objectID: AudioObjectID) -> Int {
        var address = audioPropertyAddress(
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

    func defaultInputDeviceID() -> AudioDeviceID? {
        var address = audioPropertyAddress(kAudioHardwarePropertyDefaultInputDevice)
        var objectID = AudioDeviceID(kAudioObjectUnknown)
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(systemObject, &address, 0, nil, &dataSize, &objectID)
        guard status == noErr, objectID != AudioDeviceID(kAudioObjectUnknown) else { return nil }
        return objectID
    }
}

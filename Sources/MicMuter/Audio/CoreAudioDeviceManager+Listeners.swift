import CoreAudio

extension CoreAudioDeviceManager {
    func removeDeviceListeners(for device: AudioInputDevice) {
        removeListener(key: "device.\(device.uid).mute")
        removeListener(key: "device.\(device.uid).volume")
    }

    func addListener(
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

    func removeListener(key: String) {
        guard let listener = listeners.removeValue(forKey: key) else { return }
        var address = listener.address
        AudioObjectRemovePropertyListenerBlock(listener.objectID, &address, .main, listener.block)
    }
}

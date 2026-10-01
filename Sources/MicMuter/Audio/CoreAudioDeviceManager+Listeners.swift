import CoreAudio
import Foundation

extension CoreAudioDeviceManager {
    enum AudioChange: Sendable {
        case topology
        case defaultInput
        case device(String)
    }

    func removeDeviceListeners(for device: AudioInputDevice) {
        for suffix in ["mute", "volume"] {
            let key = "device.\(device.uid).\(suffix)"
            removeListener(key: key)
            failedListenerKeys.remove(key)
        }
    }

    func addListener(
        key: String, objectID: AudioObjectID, address: AudioObjectPropertyAddress, change: AudioChange
    ) {
        if let existing = listeners[key] {
            if existing.objectID == objectID { return }
            removeListener(key: key)
        }
        let id = UUID()
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor [weak self] in
                guard let self, self.listeners[key]?.id == id else { return }
                self.scheduleRefresh(for: change)
            }
        }
        let status = monitor.addListener(objectID: objectID, address: address, block: block)
        guard status == noErr else {
            if failedListenerKeys.insert(key).inserted {
                logger.error("Listener registration failed for \(key, privacy: .public): \(status)")
            }
            return
        }
        failedListenerKeys.remove(key)
        listeners[key] = ListenerRegistration(id: id, objectID: objectID, address: address, block: block)
    }

    func removeListener(key: String) {
        guard let listener = listeners.removeValue(forKey: key) else { return }
        let status = monitor.removeListener(
            objectID: listener.objectID, address: listener.address, block: listener.block
        )
        if status != noErr {
            logger.error("Listener removal failed for \(key, privacy: .public): \(status)")
        }
    }

    func scheduleRefresh(for change: AudioChange) {
        guard isMonitoring else { return }
        switch change {
        case .topology: topologyChanged = true
        case .defaultInput: defaultInputChanged = true
        case .device(let uid): changedDeviceUIDs.insert(uid)
        }
        guard refreshTask == nil else { return }
        refreshTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard !Task.isCancelled, let self, self.isMonitoring else { return }
            self.refreshTask = nil
            let refreshTopology = self.topologyChanged
            let refreshDefault = self.defaultInputChanged
            let deviceUIDs = self.changedDeviceUIDs
            self.topologyChanged = false
            self.defaultInputChanged = false
            self.changedDeviceUIDs.removeAll()
            if refreshTopology {
                self.refresh()
            } else {
                if refreshDefault { self.refreshDefaultInput() }
                for device in self.inputDevices where deviceUIDs.contains(device.uid) {
                    self.reconcileStaleFallbackState(for: device)
                }
                self.onChange?()
                self.scheduleMonitoringRetry()
            }
        }
    }

    func scheduleMonitoringRetry() {
        let needsRetry =
            !failedListenerKeys.isEmpty || deviceEnumerationFailed || defaultInputReadFailed
        guard isMonitoring else { return }
        guard needsRetry else {
            retryTask?.cancel()
            retryTask = nil
            return
        }
        guard retryTask == nil else { return }
        retryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, let self, self.isMonitoring else { return }
            self.retryTask = nil
            self.refresh()
        }
    }
}

extension CoreAudioDeviceMonitor {
    func addListener(
        objectID: AudioObjectID, address: AudioObjectPropertyAddress, block: @escaping AudioObjectPropertyListenerBlock
    ) -> OSStatus {
        var address = address
        return AudioObjectAddPropertyListenerBlock(objectID, &address, .main, block)
    }

    func removeListener(
        objectID: AudioObjectID, address: AudioObjectPropertyAddress, block: @escaping AudioObjectPropertyListenerBlock
    ) -> OSStatus {
        var address = address
        return AudioObjectRemovePropertyListenerBlock(objectID, &address, .main, block)
    }
}

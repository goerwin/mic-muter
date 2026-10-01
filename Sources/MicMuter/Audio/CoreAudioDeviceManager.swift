import CoreAudio
import Foundation
import OSLog

@MainActor
final class CoreAudioDeviceManager {
    struct ListenerRegistration {
        let id: UUID
        let objectID: AudioObjectID
        let address: AudioObjectPropertyAddress
        let block: AudioObjectPropertyListenerBlock
    }

    private(set) var inputDevices: [AudioInputDevice] = []
    private(set) var defaultInputUID: String?
    var onChange: (() -> Void)?

    let systemObject = AudioObjectID(kAudioObjectSystemObject)
    var listeners: [String: ListenerRegistration] = [:]
    let monitor: any AudioDeviceMonitoring
    var isMonitoring = false
    var refreshTask: Task<Void, Never>?
    var retryTask: Task<Void, Never>?
    var topologyChanged = false
    var defaultInputChanged = false
    var changedDeviceUIDs: Set<String> = []
    var failedListenerKeys: Set<String> = []
    var deviceEnumerationFailed = false
    var defaultInputReadFailed = false
    let logger = Logger(subsystem: "com.goerwin.MicMuter", category: "AudioMonitoring")
    private let volumeStore: any VolumeStoring
    private let propertyAccess: any AudioDevicePropertyAccess

    init(
        volumeStore: any VolumeStoring, propertyAccess: any AudioDevicePropertyAccess,
        monitor: (any AudioDeviceMonitoring)? = nil
    ) {
        self.volumeStore = volumeStore
        self.propertyAccess = propertyAccess
        self.monitor = monitor ?? CoreAudioDeviceMonitor()
    }

    func startMonitoring() {
        guard !isMonitoring else {
            onChange?()
            return
        }
        isMonitoring = true
        refresh()
    }

    func stopMonitoring() {
        isMonitoring = false
        refreshTask?.cancel()
        refreshTask = nil
        retryTask?.cancel()
        retryTask = nil
        topologyChanged = false
        defaultInputChanged = false
        changedDeviceUIDs.removeAll()
        deviceEnumerationFailed = false
        defaultInputReadFailed = false
        for key in Array(listeners.keys) { removeListener(key: key) }
        failedListenerKeys.removeAll()
    }

    private func registerSystemListeners() {
        addListener(
            key: "system.devices",
            objectID: systemObject,
            address: audioPropertyAddress(kAudioHardwarePropertyDevices), change: .topology
        )
        addListener(
            key: "system.defaultInput",
            objectID: systemObject,
            address: audioPropertyAddress(kAudioHardwarePropertyDefaultInputDevice), change: .defaultInput
        )
    }

    func refresh() {
        guard isMonitoring else { return }
        registerSystemListeners()
        do {
            updateDevices(try monitor.enumerateInputDevices())
            deviceEnumerationFailed = false
        } catch {
            if !deviceEnumerationFailed {
                logger.error("Input device enumeration failed: \(String(describing: error), privacy: .public)")
            }
            deviceEnumerationFailed = true
        }

        refreshDefaultInput()
        onChange?()
        scheduleMonitoringRetry()
    }

    private func updateDevices(_ newDevices: [AudioInputDevice]) {
        for device in inputDevices
        where !newDevices.contains(where: { $0.uid == device.uid && $0.objectID == device.objectID }) {
            removeDeviceListeners(for: device)
        }
        for device in newDevices {
            addListener(
                key: "device.\(device.uid).mute",
                objectID: device.objectID,
                address: audioPropertyAddress(
                    kAudioDevicePropertyMute,
                    scope: kAudioDevicePropertyScopeInput, element: kAudioObjectPropertyElementWildcard
                ), change: .device(device.uid)
            )
            addListener(
                key: "device.\(device.uid).volume",
                objectID: device.objectID,
                address: audioPropertyAddress(
                    kAudioDevicePropertyVolumeScalar,
                    scope: kAudioDevicePropertyScopeInput, element: kAudioObjectPropertyElementWildcard
                ), change: .device(device.uid)
            )
        }

        inputDevices = newDevices
        reconcileStaleFallbackState()
    }

    func refreshDefaultInput() {
        do {
            let defaultDeviceID = try monitor.defaultInputDeviceID()
            defaultInputReadFailed = false
            defaultInputUID = defaultDeviceID.flatMap { id in
                inputDevices.first(where: { $0.objectID == id })?.uid
            }
        } catch {
            if !defaultInputReadFailed {
                logger.error("Default input device read failed: \(String(describing: error), privacy: .public)")
            }
            defaultInputReadFailed = true
        }
    }

    // Clear externally resolved fallback mutes here so status queries stay read-only.
    private func reconcileStaleFallbackState() {
        for device in inputDevices {
            reconcileStaleFallbackState(for: device)
        }
    }

    func reconcileStaleFallbackState(for device: AudioInputDevice) {
        guard let saved = volumeStore.fallbackState(forDeviceUID: device.uid), saved.phase == .muted,
            let volumes = completeVolumeValues(for: device), !volumes.isEmpty,
            volumes.map(\.element) == saved.values.map(\.element)
        else {
            return
        }

        if !inputIsZero(volumes) {
            volumeStore.clearFallbackState(forDeviceUID: device.uid)
        }
    }

    func state(for device: AudioInputDevice) -> AudioDeviceState {
        let saved = volumeStore.fallbackState(forDeviceUID: device.uid)
        return AudioDeviceState(
            status: status(for: device, saved: saved), canControl: canControl(device),
            hasSavedInputLevel: saved != nil, pendingMute: saved?.pendingMute
        )
    }

    func canControl(_ device: AudioInputDevice) -> Bool {
        propertyAccess.canSetMute(for: device) || hasWritableInputVolumes(for: device)
    }

    func status(for device: AudioInputDevice) -> AudioDeviceStatus {
        status(for: device, saved: volumeStore.fallbackState(forDeviceUID: device.uid))
    }

    private func status(for device: AudioInputDevice, saved: VolumeFallbackState?) -> AudioDeviceStatus {
        let muteValue = propertyAccess.muteValue(for: device)
        if saved?.pendingMute != nil {
            return .unknown
        }

        if muteValue == true {
            return .muted
        }
        guard let volumes = completeVolumeValues(for: device) else { return .unknown }
        if let saved {
            guard !volumes.isEmpty, volumes.map(\.element) == saved.values.map(\.element) else { return .unknown }
            if inputIsZero(volumes) { return .muted }
        }
        if !volumes.isEmpty {
            return inputIsZero(volumes) ? .inputSilent : .unmuted
        }
        return muteValue == false ? .unmuted : .unknown
    }

    func setMuted(_ shouldMute: Bool, for device: AudioInputDevice) throws {
        if let saved = volumeStore.fallbackState(forDeviceUID: device.uid), saved.pendingMute != nil {
            try restoreInputLevel(for: device, phase: shouldMute ? .muting : .restoring)
            if !shouldMute {
                onChange?()
                return
            }
        }

        if shouldMute {
            if let saved = volumeStore.fallbackState(forDeviceUID: device.uid) {
                guard let volumes = completeVolumeValues(for: device), !volumes.isEmpty,
                    volumes.map(\.element) == saved.values.map(\.element)
                else { throw AudioDeviceError.inputLevelReadFailed }
                if inputIsZero(volumes) { return }
                volumeStore.clearFallbackState(forDeviceUID: device.uid)
            }
            if propertyAccess.canSetMute(for: device), propertyAccess.setMute(true, for: device) {
                onChange?()
                return
            }
            try muteByZeroingInput(for: device)
            return
        }

        if volumeStore.fallbackState(forDeviceUID: device.uid) != nil {
            try restoreInputLevel(for: device)
            onChange?()
            return
        }

        if propertyAccess.canSetMute(for: device), propertyAccess.setMute(false, for: device) {
            onChange?()
            return
        }

        guard let volumes = completeVolumeValues(for: device) else { throw AudioDeviceError.inputLevelReadFailed }
        if inputIsZero(volumes) {
            throw AudioDeviceError.missingSavedInputLevel
        }

        throw AudioDeviceError.unsupported
    }

    private func hasWritableInputVolumes(for device: AudioInputDevice) -> Bool {
        let controls = propertyAccess.volumeProperties(for: device)
        return !controls.isEmpty && controls.allSatisfy(\.isWritable)
    }

    private func completeVolumeValues(for device: AudioInputDevice) -> [VolumeSnapshot]? {
        let controls = propertyAccess.volumeProperties(for: device)
        guard let values = propertyAccess.volumeValues(for: device),
            values.map(\.element) == controls.map(\.element),
            values.allSatisfy({ $0.value.isFinite && (0...1).contains($0.value) })
        else { return nil }
        return values
    }

    private func inputIsZero(_ values: [VolumeSnapshot]) -> Bool {
        !values.isEmpty && values.allSatisfy { $0.value <= 0.0001 }
    }

    private func muteByZeroingInput(for device: AudioInputDevice) throws {
        let controls = propertyAccess.volumeProperties(for: device)
        guard !controls.isEmpty, controls.allSatisfy(\.isWritable)
        else {
            throw AudioDeviceError.unsupported
        }
        guard let currentValues = completeVolumeValues(for: device) else {
            throw AudioDeviceError.inputLevelReadFailed
        }
        guard !inputIsZero(currentValues) else { throw AudioDeviceError.missingSavedInputLevel }

        try volumeStore.saveFallbackState(
            VolumeFallbackState(values: currentValues, phase: .muting), forDeviceUID: device.uid
        )

        let zeroValues = currentValues.map { VolumeSnapshot(element: $0.element, value: 0) }
        guard propertyAccess.writeVolumeValues(zeroValues, for: device) else {
            if propertyAccess.writeVolumeValues(currentValues, for: device) {
                volumeStore.clearFallbackState(forDeviceUID: device.uid)
            }
            throw AudioDeviceError.inputLevelWriteFailed
        }
        try volumeStore.saveFallbackState(
            VolumeFallbackState(values: currentValues, phase: .muted), forDeviceUID: device.uid
        )
        onChange?()
    }

    private func restoreInputLevel(
        for device: AudioInputDevice, phase: VolumeFallbackState.Phase = .restoring
    ) throws {
        guard var saved = volumeStore.fallbackState(forDeviceUID: device.uid) else {
            throw AudioDeviceError.missingSavedInputLevel
        }
        let controls = propertyAccess.volumeProperties(for: device)
        guard !saved.values.isEmpty, saved.values.map(\.element) == controls.map(\.element),
            controls.allSatisfy(\.isWritable),
            saved.values.allSatisfy({ $0.value.isFinite && (0...1).contains($0.value) })
        else { throw AudioDeviceError.unsupported }
        saved.phase = phase
        try volumeStore.saveFallbackState(saved, forDeviceUID: device.uid)
        guard propertyAccess.writeVolumeValues(saved.values, for: device) else {
            throw AudioDeviceError.inputLevelWriteFailed
        }
        volumeStore.clearFallbackState(forDeviceUID: device.uid)
    }
}

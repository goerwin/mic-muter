import CoreAudio
import Foundation

@testable import MicMuterCore

@MainActor
final class MockAudioManager: AudioDeviceManaging {
    var inputDevices: [AudioInputDevice] = []
    var defaultInputUID: String?
    var onChange: (() -> Void)?
    var canControlValue = true
    var canControlHandler: ((AudioInputDevice) -> Bool)?
    var statusValue: AudioDeviceStatus = .unmuted
    var statusHandler: ((AudioInputDevice) -> AudioDeviceStatus)?
    var hasSavedLevel = false
    var pendingMute: Bool?
    var stateHandler: ((AudioInputDevice) -> AudioDeviceState)?
    var setMutedHandler: ((Bool, AudioInputDevice) throws -> Void)?

    func startMonitoring() { onChange?() }
    func stopMonitoring() {}

    func state(for device: AudioInputDevice) -> AudioDeviceState {
        stateHandler?(device)
            ?? AudioDeviceState(
                status: status(for: device), canControl: canControl(device),
                hasSavedInputLevel: hasSavedLevel, pendingMute: pendingMute
            )
    }

    func canControl(_ device: AudioInputDevice) -> Bool {
        canControlHandler?(device) ?? canControlValue
    }

    func status(for device: AudioInputDevice) -> AudioDeviceStatus {
        statusHandler?(device) ?? statusValue
    }

    func hasSavedInputLevel(for device: AudioInputDevice) -> Bool { hasSavedLevel }

    func setMuted(_ shouldMute: Bool, for device: AudioInputDevice) throws {
        try setMutedHandler?(shouldMute, device)
        statusValue = shouldMute ? .muted : .unmuted
        onChange?()
    }
}

@MainActor
final class MockAudioDevicePropertyAccess: AudioDevicePropertyAccess {
    struct VolumeWriteOutcome {
        let succeeds: Bool
        let appliedElementsOnFailure: Set<UInt32>

        static let success = Self(succeeds: true, appliedElementsOnFailure: [])

        static func failure(applying elements: Set<UInt32> = []) -> Self {
            Self(succeeds: false, appliedElementsOnFailure: elements)
        }
    }

    var writableMuteUIDs: Set<String> = []
    var muteValues: [String: Bool] = [:]
    var muteWriteSucceeds = true
    var volumePropertiesByUID: [String: [AudioInputVolumeProperty]] = [:]
    var volumeValuesByUID: [String: [VolumeSnapshot]] = [:]
    var unreadableVolumeUIDs: Set<String> = []
    var volumeWriteOutcomes: [VolumeWriteOutcome] = []
    var volumeWriteAttempts: [[VolumeSnapshot]] = []

    func muteValue(for device: AudioInputDevice) -> Bool? {
        muteValues[device.uid]
    }

    func canSetMute(for device: AudioInputDevice) -> Bool {
        writableMuteUIDs.contains(device.uid)
    }

    func setMute(_ muted: Bool, for device: AudioInputDevice) -> Bool {
        guard canSetMute(for: device), muteWriteSucceeds else { return false }
        muteValues[device.uid] = muted
        return true
    }

    func volumeProperties(for device: AudioInputDevice) -> [AudioInputVolumeProperty] {
        volumePropertiesByUID[device.uid] ?? []
    }

    func volumeValues(for device: AudioInputDevice) -> [VolumeSnapshot]? {
        unreadableVolumeUIDs.contains(device.uid) ? nil : volumeValuesByUID[device.uid] ?? []
    }

    func writeVolumeValues(_ values: [VolumeSnapshot], for device: AudioInputDevice) -> Bool {
        volumeWriteAttempts.append(values)
        let outcome = volumeWriteOutcomes.isEmpty ? .success : volumeWriteOutcomes.removeFirst()
        let appliedElements =
            outcome.succeeds
            ? Set(values.map(\.element))
            : outcome.appliedElementsOnFailure
        var currentValues = volumeValuesByUID[device.uid] ?? []
        for index in currentValues.indices where appliedElements.contains(currentValues[index].element) {
            if let replacement = values.first(where: { $0.element == currentValues[index].element }) {
                currentValues[index] = replacement
            }
        }
        volumeValuesByUID[device.uid] = currentValues
        return outcome.succeeds
    }
}

@MainActor
final class MockAudioDeviceMonitor: AudioDeviceMonitoring {
    struct Registration {
        let objectID: AudioObjectID
        let address: AudioObjectPropertyAddress
        let block: AudioObjectPropertyListenerBlock
    }

    var devices: [AudioInputDevice] = []
    var defaultDeviceID: AudioDeviceID?
    var registrations: [Registration] = []
    var removed: [Registration] = []
    var registrationFailuresRemaining = 0
    var enumerationCount = 0

    func enumerateInputDevices() -> [AudioInputDevice] {
        enumerationCount += 1
        return devices
    }

    func defaultInputDeviceID() -> AudioDeviceID? { defaultDeviceID }

    func addListener(
        objectID: AudioObjectID, address: AudioObjectPropertyAddress, block: @escaping AudioObjectPropertyListenerBlock
    ) -> OSStatus {
        if registrationFailuresRemaining > 0 {
            registrationFailuresRemaining -= 1
            return kAudioHardwareUnspecifiedError
        }
        registrations.append(Registration(objectID: objectID, address: address, block: block))
        return noErr
    }

    func removeListener(
        objectID: AudioObjectID, address: AudioObjectPropertyAddress, block: @escaping AudioObjectPropertyListenerBlock
    ) -> OSStatus {
        removed.append(Registration(objectID: objectID, address: address, block: block))
        registrations.removeAll {
            $0.objectID == objectID && $0.address.mSelector == address.mSelector
                && $0.address.mScope == address.mScope && $0.address.mElement == address.mElement
        }
        return noErr
    }

    func notify(objectID: AudioObjectID, selector: AudioObjectPropertySelector, element: UInt32 = 0) {
        for registration in registrations
        where registration.objectID == objectID
            && registration.address.mSelector == selector
            && (registration.address.mElement == element
                || registration.address.mElement == kAudioObjectPropertyElementWildcard)
        {
            var address = registration.address
            address.mElement = element
            withUnsafePointer(to: &address) { registration.block(1, $0) }
        }
    }
}

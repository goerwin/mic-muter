import XCTest

@testable import MicMuterCore

@MainActor
final class CoreAudioDeviceManagerTests: XCTestCase {
    private let originalLevels = [
        VolumeSnapshot(element: 1, value: 0.7),
        VolumeSnapshot(element: 2, value: 0.4),
    ]

    private func makeDevice() -> AudioInputDevice {
        AudioInputDevice(uid: "device-1", name: "Test Mic", objectID: 1, inputChannelCount: 2)
    }

    private func makeManager(
        properties: MockAudioDevicePropertyAccess
    ) -> (CoreAudioDeviceManager, VolumeStore) {
        let domain = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        addTeardownBlock { defaults.removePersistentDomain(forName: domain) }
        let volumeStore = VolumeStore(defaults: defaults)
        return (
            CoreAudioDeviceManager(volumeStore: volumeStore, propertyAccess: properties),
            volumeStore
        )
    }

    private func configureWritableVolumes(
        _ properties: MockAudioDevicePropertyAccess,
        for device: AudioInputDevice,
        values: [VolumeSnapshot]? = nil
    ) {
        properties.volumePropertiesByUID[device.uid] = originalLevels.map {
            AudioInputVolumeProperty(element: $0.element, isWritable: true)
        }
        properties.volumeValuesByUID[device.uid] = values ?? originalLevels
    }

    func testVolumeFallbackMutesAndRestoresEveryChannel() throws {
        let device = makeDevice()
        let properties = MockAudioDevicePropertyAccess()
        configureWritableVolumes(properties, for: device)
        let (manager, store) = makeManager(properties: properties)

        try manager.setMuted(true, for: device)

        XCTAssertEqual(
            properties.volumeValues(for: device),
            originalLevels.map { VolumeSnapshot(element: $0.element, value: 0) }
        )
        XCTAssertEqual(store.fallbackState(forDeviceUID: device.uid)?.values, originalLevels)
        XCTAssertEqual(store.fallbackState(forDeviceUID: device.uid)?.phase, .muted)
        XCTAssertEqual(manager.status(for: device), .muted)

        try manager.setMuted(false, for: device)

        XCTAssertEqual(properties.volumeValues(for: device), originalLevels)
        XCTAssertNil(store.fallbackState(forDeviceUID: device.uid))
    }

    func testWritableHardwareMuteTakesPrecedenceOverVolumeFallback() throws {
        let device = makeDevice()
        let properties = MockAudioDevicePropertyAccess()
        properties.writableMuteUIDs.insert(device.uid)
        properties.muteValues[device.uid] = false
        configureWritableVolumes(properties, for: device)
        let (manager, store) = makeManager(properties: properties)

        try manager.setMuted(true, for: device)

        XCTAssertEqual(properties.muteValues[device.uid], true)
        XCTAssertTrue(properties.volumeWriteAttempts.isEmpty)
        XCTAssertNil(store.fallbackState(forDeviceUID: device.uid))
    }

    func testReadOnlyVolumesAreNotUsedAsMuteFallback() {
        let device = makeDevice()
        let properties = MockAudioDevicePropertyAccess()
        properties.volumePropertiesByUID[device.uid] = [
            AudioInputVolumeProperty(element: 1, isWritable: false)
        ]
        properties.volumeValuesByUID[device.uid] = [VolumeSnapshot(element: 1, value: 0.7)]
        let (manager, store) = makeManager(properties: properties)

        XCTAssertFalse(manager.canControl(device))
        XCTAssertThrowsError(try manager.setMuted(true, for: device))
        XCTAssertTrue(properties.volumeWriteAttempts.isEmpty)
        XCTAssertNil(store.fallbackState(forDeviceUID: device.uid))
    }

    func testFailedPartialMuteWriteRetainsSnapshotForRetry() throws {
        let device = makeDevice()
        let properties = MockAudioDevicePropertyAccess()
        configureWritableVolumes(properties, for: device)
        properties.volumeWriteOutcomes = [
            .failure(applying: [1]),
            .failure(),
        ]
        let (manager, store) = makeManager(properties: properties)

        XCTAssertThrowsError(try manager.setMuted(true, for: device))
        XCTAssertEqual(properties.volumeValuesByUID[device.uid]?.first?.value, 0)
        XCTAssertEqual(store.fallbackState(forDeviceUID: device.uid)?.values, originalLevels)
        XCTAssertEqual(store.fallbackState(forDeviceUID: device.uid)?.phase, .muting)
        XCTAssertEqual(manager.status(for: device), .unknown)

        // A property listener refresh must not discard the snapshot after a partial write.
        manager.reconcileStaleFallbackState(for: device)
        XCTAssertEqual(store.fallbackState(forDeviceUID: device.uid)?.values, originalLevels)

        // Retry the user's mute action: restore the old level, then mute again.
        try manager.setMuted(true, for: device)
        XCTAssertEqual(
            properties.volumeValues(for: device),
            originalLevels.map { VolumeSnapshot(element: $0.element, value: 0) }
        )
        XCTAssertEqual(store.fallbackState(forDeviceUID: device.uid)?.phase, .muted)
        XCTAssertEqual(store.fallbackState(forDeviceUID: device.uid)?.values, originalLevels)
    }

    func testFailedPartialRestoreRetainsSnapshotAcrossRefresh() throws {
        let device = makeDevice()
        let properties = MockAudioDevicePropertyAccess()
        configureWritableVolumes(properties, for: device)
        let (manager, store) = makeManager(properties: properties)
        try manager.setMuted(true, for: device)
        properties.volumeWriteOutcomes = [.failure(applying: [1])]

        XCTAssertThrowsError(try manager.setMuted(false, for: device))
        XCTAssertEqual(store.fallbackState(forDeviceUID: device.uid)?.phase, .restoring)
        XCTAssertEqual(store.fallbackState(forDeviceUID: device.uid)?.values, originalLevels)
        XCTAssertEqual(manager.status(for: device), .unknown)

        manager.reconcileStaleFallbackState(for: device)
        XCTAssertEqual(store.fallbackState(forDeviceUID: device.uid)?.values, originalLevels)

        try manager.setMuted(false, for: device)
        XCTAssertEqual(properties.volumeValues(for: device), originalLevels)
        XCTAssertNil(store.fallbackState(forDeviceUID: device.uid))
    }

    func testStatusIsReadOnlyAndRefreshClearsExternallyChangedFallbackState() throws {
        let device = makeDevice()
        let properties = MockAudioDevicePropertyAccess()
        configureWritableVolumes(properties, for: device)
        let (manager, store) = makeManager(properties: properties)
        try manager.setMuted(true, for: device)
        properties.volumeValuesByUID[device.uid] = [
            VolumeSnapshot(element: 1, value: 0.6),
            VolumeSnapshot(element: 2, value: 0.4),
        ]

        XCTAssertEqual(manager.status(for: device), .unmuted)
        XCTAssertEqual(store.fallbackState(forDeviceUID: device.uid)?.phase, .muted)
        XCTAssertEqual(store.fallbackState(forDeviceUID: device.uid)?.values, originalLevels)

        manager.reconcileStaleFallbackState(for: device)
        XCTAssertNil(store.fallbackState(forDeviceUID: device.uid))
    }

    func testUnreadableOrPartialVolumesPreserveRecoveryAndDoNotConfirmMute() throws {
        let device = makeDevice()
        let properties = MockAudioDevicePropertyAccess()
        configureWritableVolumes(properties, for: device)
        let (manager, store) = makeManager(properties: properties)
        try manager.setMuted(true, for: device)

        for values in [[], [VolumeSnapshot(element: 1, value: 0)]] {
            properties.volumeValuesByUID[device.uid] = values
            manager.reconcileStaleFallbackState(for: device)
            XCTAssertEqual(store.fallbackState(forDeviceUID: device.uid)?.values, originalLevels)
            XCTAssertEqual(manager.status(for: device), .unknown)
        }
        properties.unreadableVolumeUIDs.insert(device.uid)
        manager.reconcileStaleFallbackState(for: device)
        XCTAssertEqual(store.fallbackState(forDeviceUID: device.uid)?.values, originalLevels)
        XCTAssertEqual(manager.status(for: device), .unknown)
        properties.unreadableVolumeUIDs.remove(device.uid)
        properties.volumeValuesByUID[device.uid] = originalLevels.map { VolumeSnapshot(element: $0.element, value: 0) }
        try manager.setMuted(false, for: device)
        XCTAssertEqual(properties.volumeValues(for: device), originalLevels)
    }

    func testMuteWhileFallbackReadIsUnknownNeverOverwritesSnapshot() throws {
        let device = makeDevice()
        let properties = MockAudioDevicePropertyAccess()
        configureWritableVolumes(properties, for: device)
        let (manager, store) = makeManager(properties: properties)
        try manager.setMuted(true, for: device)
        properties.unreadableVolumeUIDs.insert(device.uid)
        let attempts = properties.volumeWriteAttempts.count

        XCTAssertThrowsError(try manager.setMuted(true, for: device))
        XCTAssertEqual(store.fallbackState(forDeviceUID: device.uid)?.values, originalLevels)
        XCTAssertEqual(properties.volumeWriteAttempts.count, attempts)
    }

    func testInvalidVolumeReadNeverConfirmsMuteOrWritesHardware() {
        let device = makeDevice()
        let properties = MockAudioDevicePropertyAccess()
        configureWritableVolumes(properties, for: device)
        let (manager, _) = makeManager(properties: properties)
        for value in [Float.nan, .infinity, -0.1, 1.1] {
            properties.volumeValuesByUID[device.uid] = [
                VolumeSnapshot(element: 1, value: value), VolumeSnapshot(element: 2, value: 0),
            ]
            XCTAssertEqual(manager.status(for: device), .unknown)
            XCTAssertThrowsError(try manager.setMuted(true, for: device))
        }
        XCTAssertTrue(properties.volumeWriteAttempts.isEmpty)
    }
}

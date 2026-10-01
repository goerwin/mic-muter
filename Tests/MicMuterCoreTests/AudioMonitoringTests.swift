import CoreAudio
import XCTest

@testable import MicMuterCore

@MainActor
final class AudioMonitoringTests: XCTestCase {
    private func makeDevice(objectID: AudioDeviceID = 20) -> AudioInputDevice {
        AudioInputDevice(uid: "monitor-device", name: "Monitor Mic", objectID: objectID, inputChannelCount: 2)
    }

    private func makeManager(monitor: MockAudioDeviceMonitor) -> CoreAudioDeviceManager {
        let domain = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        addTeardownBlock { defaults.removePersistentDomain(forName: domain) }
        return CoreAudioDeviceManager(
            volumeStore: VolumeStore(defaults: defaults), propertyAccess: MockAudioDevicePropertyAccess(),
            monitor: monitor
        )
    }

    func testObjectIDReplacementReconnectAndTeardown() {
        let monitor = MockAudioDeviceMonitor()
        monitor.devices = [makeDevice()]
        let manager = makeManager(monitor: monitor)
        manager.startMonitoring()
        manager.startMonitoring()
        XCTAssertEqual(monitor.registrations.count, 4)

        monitor.devices = [makeDevice(objectID: 21)]
        manager.refresh()
        XCTAssertFalse(monitor.registrations.contains { $0.objectID == 20 })
        XCTAssertEqual(monitor.registrations.filter { $0.objectID == 21 }.count, 2)
        XCTAssertEqual(monitor.removed.count, 2)

        monitor.devices = []
        manager.refresh()
        XCTAssertEqual(monitor.registrations.count, 2)
        monitor.devices = [makeDevice(objectID: 22)]
        manager.refresh()
        XCTAssertEqual(monitor.registrations.count, 4)

        let staleBlock = monitor.registrations[0].block
        manager.stopMonitoring()
        XCTAssertTrue(monitor.registrations.isEmpty)
        XCTAssertNil(manager.refreshTask)
        var staleAddress = audioPropertyAddress(kAudioHardwarePropertyDevices)
        withUnsafePointer(to: &staleAddress) { staleBlock(1, $0) }
        manager.startMonitoring()
        XCTAssertEqual(monitor.registrations.count, 4)
        manager.stopMonitoring()
    }

    func testFailedRegistrationRetriesEvenWhenUIDIsUnchanged() async {
        let monitor = MockAudioDeviceMonitor()
        monitor.devices = [makeDevice()]
        monitor.registrationFailuresRemaining = 1
        let manager = makeManager(monitor: monitor)
        manager.startMonitoring()
        defer { manager.stopMonitoring() }
        XCTAssertEqual(monitor.registrations.count, 3)
        XCTAssertNotNil(manager.retryTask)

        let retry = manager.retryTask
        await retry?.value

        XCTAssertEqual(monitor.registrations.count, 4)
        XCTAssertTrue(manager.failedListenerKeys.isEmpty)
    }

    func testChannelNotificationsAreCoalescedWithoutDeviceEnumeration() async {
        let monitor = MockAudioDeviceMonitor()
        let device = makeDevice()
        monitor.devices = [device]
        let manager = makeManager(monitor: monitor)
        manager.startMonitoring()
        defer { manager.stopMonitoring() }
        let changed = expectation(description: "one audio update")
        changed.assertForOverFulfill = true
        manager.onChange = { changed.fulfill() }

        monitor.notify(objectID: device.objectID, selector: kAudioDevicePropertyVolumeScalar, element: 1)
        monitor.notify(objectID: device.objectID, selector: kAudioDevicePropertyVolumeScalar, element: 2)

        await fulfillment(of: [changed], timeout: 1)
        XCTAssertEqual(monitor.enumerationCount, 1)
    }

    func testDefaultInputNotificationDoesNotEnumerateDevices() async {
        let monitor = MockAudioDeviceMonitor()
        let device = makeDevice()
        monitor.devices = [device]
        let manager = makeManager(monitor: monitor)
        manager.startMonitoring()
        defer { manager.stopMonitoring() }
        XCTAssertNil(manager.defaultInputUID)
        let changed = expectation(description: "default input update")
        manager.onChange = { changed.fulfill() }
        monitor.defaultDeviceID = device.objectID

        monitor.notify(
            objectID: AudioObjectID(kAudioObjectSystemObject), selector: kAudioHardwarePropertyDefaultInputDevice
        )

        await fulfillment(of: [changed], timeout: 1)
        XCTAssertEqual(manager.defaultInputUID, device.uid)
        XCTAssertEqual(monitor.enumerationCount, 1)
    }
}

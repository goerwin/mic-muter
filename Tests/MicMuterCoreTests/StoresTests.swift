import XCTest

@testable import MicMuterCore

@MainActor
final class StoresTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        let name = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }

    func testDeviceSelectionRoundTrip() {
        let defaults = freshDefaults()
        let store = DeviceSelectionStore(defaults: defaults)

        XCTAssertNil(store.selectedDeviceUID)
        store.saveSelection(uid: "uid-1", name: "Mic One")
        XCTAssertEqual(store.selectedDeviceUID, "uid-1")
        XCTAssertEqual(store.selectedDeviceNameSnapshot, "Mic One")

        store.saveNameSnapshot("Mic One Renamed", for: "uid-1")
        XCTAssertEqual(store.selectedDeviceNameSnapshot, "Mic One Renamed")

        store.saveNameSnapshot("Other", for: "uid-2")
        XCTAssertEqual(store.selectedDeviceNameSnapshot, "Mic One Renamed")

        store.clearSelection()
        XCTAssertNil(store.selectedDeviceUID)
        XCTAssertNil(store.selectedDeviceNameSnapshot)
    }

    func testVolumeStoreRoundTrip() {
        let defaults = freshDefaults()
        let store = VolumeStore(defaults: defaults)
        let uid = "dev-1"

        XCTAssertNil(store.savedInputLevel(forDeviceUID: uid))
        XCTAssertFalse(store.isFallbackMuteActive(forDeviceUID: uid))
        XCTAssertFalse(store.isRestorePending(forDeviceUID: uid))

        store.saveInputLevel([VolumeSnapshot(element: 1, value: 0.5)], forDeviceUID: uid)
        XCTAssertEqual(store.savedInputLevel(forDeviceUID: uid), [VolumeSnapshot(element: 1, value: 0.5)])

        store.setFallbackMuteActive(true, forDeviceUID: uid)
        XCTAssertTrue(store.isFallbackMuteActive(forDeviceUID: uid))
        store.setRestorePending(true, forDeviceUID: uid)
        XCTAssertTrue(store.isRestorePending(forDeviceUID: uid))

        store.clearSavedInputLevel(forDeviceUID: uid)
        XCTAssertNil(store.savedInputLevel(forDeviceUID: uid))
        XCTAssertFalse(store.isFallbackMuteActive(forDeviceUID: uid))
        XCTAssertFalse(store.isRestorePending(forDeviceUID: uid))
    }

    func testVolumeStoreReadsExistingSavedVolumeFormat() {
        let defaults = freshDefaults()
        let uid = "legacy-device"
        let legacyData = #"{"values":[{"element":1,"value":0.75}]}"#.data(using: .utf8)!
        defaults.set(legacyData, forKey: "savedInputVolume." + uid)
        defaults.set(true, forKey: "mutedByInputVolume." + uid)
        let store = VolumeStore(defaults: defaults)

        XCTAssertEqual(store.savedInputLevel(forDeviceUID: uid), [VolumeSnapshot(element: 1, value: 0.75)])
        XCTAssertTrue(store.isFallbackMuteActive(forDeviceUID: uid))
    }

    func testSettingsStoreRoundTrip() {
        let defaults = freshDefaults()
        let store = SettingsStore(defaults: defaults)

        XCTAssertFalse(store.showHUDOnToggle)
        store.showHUDOnToggle = true
        XCTAssertTrue(store.showHUDOnToggle)
        XCTAssertTrue(defaults.bool(forKey: "showHUDOnToggle"))
    }
}

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

    func testVolumeStoreRoundTrip() throws {
        let defaults = freshDefaults()
        let store = VolumeStore(defaults: defaults)
        let uid = "dev-1"

        XCTAssertNil(store.fallbackState(forDeviceUID: uid))
        for phase in [VolumeFallbackState.Phase.muting, .muted, .restoring] {
            let state = VolumeFallbackState(values: [VolumeSnapshot(element: 1, value: 0.5)], phase: phase)
            try store.saveFallbackState(state, forDeviceUID: uid)
            XCTAssertEqual(VolumeStore(defaults: defaults).fallbackState(forDeviceUID: uid), state)
        }
        store.clearFallbackState(forDeviceUID: uid)
        XCTAssertNil(store.fallbackState(forDeviceUID: uid))
    }

    func testVolumeStoreReadsExistingSavedVolumeFormat() throws {
        let defaults = freshDefaults()
        let uid = "legacy-device"
        let legacyData = #"{"values":[{"element":1,"value":0.75}]}"#.data(using: .utf8)!
        defaults.set(legacyData, forKey: "savedInputVolume." + uid)
        defaults.set(true, forKey: "mutedByInputVolume." + uid)
        let store = VolumeStore(defaults: defaults)

        XCTAssertEqual(store.fallbackState(forDeviceUID: uid)?.values, [VolumeSnapshot(element: 1, value: 0.75)])
        XCTAssertEqual(store.fallbackState(forDeviceUID: uid)?.phase, .muted)
        defaults.set(true, forKey: "inputVolumeRestorePending." + uid)
        let state = try XCTUnwrap(store.fallbackState(forDeviceUID: uid))
        XCTAssertEqual(state.pendingMute, false)
        try store.saveFallbackState(state, forDeviceUID: uid)
        XCTAssertNil(defaults.object(forKey: "savedInputVolume." + uid))
        XCTAssertEqual(VolumeStore(defaults: defaults).fallbackState(forDeviceUID: uid), state)
        store.clearFallbackState(forDeviceUID: uid)
        XCTAssertNil(store.fallbackState(forDeviceUID: uid))
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

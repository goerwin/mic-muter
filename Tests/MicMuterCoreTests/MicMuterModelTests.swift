import XCTest

@testable import MicMuterCore

@MainActor
final class MicMuterModelTests: XCTestCase {
    private func makeDevice(uid: String = "uid-1", name: String = "Mic One") -> AudioInputDevice {
        AudioInputDevice(
            uid: uid,
            name: name,
            objectID: 1,
            inputChannelCount: 1
        )
    }

    @MainActor
    private final class FakeSelection: DeviceSelectionStoring {
        var selectedDeviceUID: String?
        var selectedDeviceNameSnapshot: String?
        var nameSnapshotWriteCount = 0
        func saveSelection(uid: String, name: String) {
            selectedDeviceUID = uid
            selectedDeviceNameSnapshot = name
        }
        func saveNameSnapshot(_ name: String, for uid: String) {
            nameSnapshotWriteCount += 1
            if selectedDeviceUID == uid { selectedDeviceNameSnapshot = name }
        }
        func clearSelection() {
            selectedDeviceUID = nil
            selectedDeviceNameSnapshot = nil
        }
    }

    @MainActor
    private final class FakeSettings: SettingsStoring {
        var showHUDOnToggle = false
    }

    @MainActor
    private final class FakeLogin: LoginItemServing {
        var status: LoginItemStatus = .disabled
        var setError: Error?
        var settingsOpened = false
        func setEnabled(_ isEnabled: Bool) throws {
            if let setError { throw setError }
            status = isEnabled ? .enabled : .disabled
        }
        func openSettings() { settingsOpened = true }
    }

    @MainActor
    private final class FakeShortcuts: ShortcutRegistering {
        var handler: (() -> Void)?
        func onToggle(_ handler: @escaping () -> Void) { self.handler = handler }
    }

    private func makeModel(
        audio: any AudioDeviceManaging,
        selection injectedSelection: FakeSelection? = nil,
        settings injectedSettings: FakeSettings? = nil,
        login injectedLogin: FakeLogin? = nil,
        shortcuts injectedShortcuts: FakeShortcuts? = nil,
        feedback: (@MainActor (MicStatus, String) -> Void)? = nil
    ) -> (MicMuterModel, FakeSelection, FakeSettings, FakeLogin, FakeShortcuts) {
        let selection = injectedSelection ?? FakeSelection()
        let settings = injectedSettings ?? FakeSettings()
        let login = injectedLogin ?? FakeLogin()
        let shortcuts = injectedShortcuts ?? FakeShortcuts()
        let model = MicMuterModel(
            audio: audio,
            selectionStore: selection,
            settings: settings,
            loginService: login,
            shortcutService: shortcuts,
            onToggleFeedback: feedback,
            terminator: {}
        )
        return (model, selection, settings, login, shortcuts)
    }

    func testStartsDisconnectedWithNoDevices() {
        let audio = MockAudioManager()
        let (model, _, _, _, _) = makeModel(audio: audio)
        XCTAssertEqual(model.status, .disconnected)
        XCTAssertEqual(model.selectedInputName, "No input device")
        XCTAssertFalse(model.canToggleSelectedDevice)
    }

    func testMapsAudioStatusToMicStatus() {
        let audio = MockAudioManager()
        let device = makeDevice()
        audio.inputDevices = [device]
        audio.defaultInputUID = device.uid
        audio.statusValue = .muted
        let (model, _, _, _, _) = makeModel(audio: audio)
        XCTAssertEqual(model.status, .muted)
        XCTAssertTrue(model.canToggleSelectedDevice)
    }

    func testUnknownBecomesUnsupportedWhenUncontrollable() {
        let audio = MockAudioManager()
        let device = makeDevice()
        audio.inputDevices = [device]
        audio.defaultInputUID = device.uid
        audio.statusValue = .unknown
        audio.canControlValue = false
        let (model, _, _, _, _) = makeModel(audio: audio)
        XCTAssertEqual(model.status, .unsupported)
        XCTAssertEqual(model.controlUnavailableMessage?.isEmpty, false)
        XCTAssertFalse(model.canToggleSelectedDevice)
    }

    func testSelectPersistsAndSelectDefaultClears() {
        let audio = MockAudioManager()
        let device = makeDevice()
        audio.inputDevices = [device]
        let (model, selection, _, _, _) = makeModel(audio: audio)
        model.select(device)
        XCTAssertEqual(model.selectedDeviceUID, device.uid)
        XCTAssertEqual(selection.selectedDeviceUID, device.uid)
        model.selectDefaultInput()
        XCTAssertNil(model.selectedDeviceUID)
        XCTAssertNil(selection.selectedDeviceUID)
    }

    func testToggleMuteCallsAudioAndFiresHUDOnce() {
        let audio = MockAudioManager()
        let device = makeDevice()
        audio.inputDevices = [device]
        audio.defaultInputUID = device.uid
        audio.statusValue = .unmuted
        let settings = FakeSettings()
        settings.showHUDOnToggle = true
        var feedback: [(MicStatus, String)] = []
        let (model, _, _, _, _) = makeModel(audio: audio, settings: settings) { status, name in
            feedback.append((status, name))
        }
        model.toggleMute()
        XCTAssertEqual(audio.statusValue, .muted)
        XCTAssertEqual(feedback.count, 1)
        XCTAssertEqual(feedback.first?.0, .muted)
        XCTAssertNil(model.errorMessage)
    }

    func testToggleFailureSurfacesErrorAndDoesNotShowHUD() {
        struct Boom: Error {}
        let audio = MockAudioManager()
        let device = makeDevice()
        audio.inputDevices = [device]
        audio.defaultInputUID = device.uid
        audio.statusValue = .unmuted
        audio.setMutedHandler = { _, _ in throw Boom() }
        let settings = FakeSettings()
        settings.showHUDOnToggle = true
        var feedbackCount = 0
        let (model, _, _, _, _) = makeModel(audio: audio, settings: settings) { _, _ in
            feedbackCount += 1
        }
        model.toggleMute()
        XCTAssertNotNil(model.errorMessage)
        XCTAssertEqual(model.status, .unmuted)
        XCTAssertEqual(feedbackCount, 0)
    }

    func testLaunchAtLoginUpdatesStateAndSurfacesFailure() {
        struct Boom: Error {}
        let audio = MockAudioManager()
        let login = FakeLogin()
        let (model, _, _, _, _) = makeModel(audio: audio, login: login)

        model.setLaunchAtLogin(true)
        XCTAssertTrue(model.launchAtLoginEnabled)
        XCTAssertNil(model.launchAtLoginError)

        login.setError = Boom()
        model.setLaunchAtLogin(false)
        XCTAssertTrue(model.launchAtLoginEnabled)
        XCTAssertNotNil(model.launchAtLoginError)
    }

    func testLaunchAtLoginReflectsExternalChangeWhenOpeningOptions() {
        let login = FakeLogin()
        let (model, _, _, _, _) = makeModel(audio: MockAudioManager(), login: login)
        login.status = .enabled
        model.refreshLoginItemState()
        XCTAssertTrue(model.launchAtLoginEnabled)
        login.status = .requiresApproval
        model.refreshLoginItemState()
        XCTAssertEqual(model.launchAtLoginStatus, .requiresApproval)
        XCTAssertTrue(model.launchAtLoginEnabled)
        model.openLoginItemSettings()
        XCTAssertTrue(login.settingsOpened)
        login.status = .disabled
        model.refreshLoginItemState()
        XCTAssertFalse(model.launchAtLoginEnabled)
    }

    func testRegisteredShortcutTogglesMute() async {
        let audio = MockAudioManager()
        let device = makeDevice()
        audio.inputDevices = [device]
        audio.defaultInputUID = device.uid
        audio.statusValue = .unmuted
        let didSetMute = expectation(description: "shortcut toggles mute")
        audio.setMutedHandler = { shouldMute, _ in
            XCTAssertTrue(shouldMute)
            didSetMute.fulfill()
        }

        let (model, _, _, _, shortcuts) = makeModel(audio: audio)
        XCTAssertEqual(model.status, .unmuted)
        shortcuts.handler?()
        await fulfillment(of: [didSetMute], timeout: 1)
        XCTAssertEqual(audio.statusValue, .muted)
    }

    func testDisconnectedPlaceholderWhenSelectedDeviceMissing() {
        let audio = MockAudioManager()
        let selection = FakeSelection()
        selection.selectedDeviceUID = "missing"
        selection.selectedDeviceNameSnapshot = "Old Mic"
        let (model, _, _, _, _) = makeModel(audio: audio, selection: selection)
        XCTAssertEqual(model.status, .disconnected)
        XCTAssertTrue(model.isSelectedDeviceDisconnected)
        XCTAssertEqual(model.selectedInputName, "Old Mic")
    }

    private func makeFallbackFixture() -> (
        UserDefaults, AudioInputDevice, MockAudioDevicePropertyAccess, MockAudioDeviceMonitor
    ) {
        let domain = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        addTeardownBlock { defaults.removePersistentDomain(forName: domain) }
        let device = makeDevice()
        let properties = MockAudioDevicePropertyAccess()
        properties.volumePropertiesByUID[device.uid] = [AudioInputVolumeProperty(element: 1, isWritable: true)]
        properties.volumeValuesByUID[device.uid] = [VolumeSnapshot(element: 1, value: 0.7)]
        let monitor = MockAudioDeviceMonitor()
        monitor.devices = [device]
        monitor.defaultDeviceID = device.objectID
        return (defaults, device, properties, monitor)
    }

    func testRetryFailedUnmuteThroughModelRestoresOriginalLevels() {
        let (defaults, device, properties, monitor) = makeFallbackFixture()
        let manager = CoreAudioDeviceManager(
            volumeStore: VolumeStore(defaults: defaults), propertyAccess: properties, monitor: monitor
        )
        let (model, _, _, _, _) = makeModel(audio: manager)
        defer { model.stop() }

        model.toggleMute()
        XCTAssertEqual(model.status, .muted)
        properties.volumeWriteOutcomes = [.failure()]
        model.toggleMute()
        XCTAssertEqual(model.status, .unknown)
        XCTAssertNotNil(model.errorMessage)

        model.toggleMute()
        XCTAssertEqual(model.status, .unmuted)
        XCTAssertEqual(properties.volumeValuesByUID[device.uid]?.first?.value, 0.7)
    }

    func testRestartPreservesFailedUnmuteIntent() {
        let (defaults, device, properties, monitor) = makeFallbackFixture()
        let manager = CoreAudioDeviceManager(
            volumeStore: VolumeStore(defaults: defaults), propertyAccess: properties, monitor: monitor
        )
        let (model, _, _, _, _) = makeModel(audio: manager)
        model.toggleMute()
        properties.volumeWriteOutcomes = [.failure()]
        model.toggleMute()
        XCTAssertTrue(model.isRecoveryPending)
        model.stop()

        let restartedManager = CoreAudioDeviceManager(
            volumeStore: VolumeStore(defaults: defaults), propertyAccess: properties, monitor: monitor
        )
        let (restartedModel, _, _, _, _) = makeModel(audio: restartedManager)
        defer { restartedModel.stop() }
        XCTAssertTrue(restartedModel.isRecoveryPending)
        restartedModel.toggleMute()
        XCTAssertEqual(restartedModel.status, .unmuted)
        XCTAssertFalse(restartedModel.isRecoveryPending)
        XCTAssertEqual(properties.volumeValuesByUID[device.uid]?.first?.value, 0.7)
    }

    func testAudioNotificationsOnlyPersistNameWhenChanged() {
        let audio = MockAudioManager()
        let device = makeDevice()
        audio.inputDevices = [device]
        let selection = FakeSelection()
        selection.selectedDeviceUID = device.uid
        selection.selectedDeviceNameSnapshot = device.name
        let (model, _, _, _, _) = makeModel(audio: audio, selection: selection)
        audio.onChange?()
        audio.onChange?()
        XCTAssertEqual(selection.nameSnapshotWriteCount, 0)
        audio.inputDevices = [makeDevice(name: "Renamed Mic")]
        audio.onChange?()
        audio.onChange?()
        XCTAssertEqual(selection.nameSnapshotWriteCount, 1)
        XCTAssertEqual(model.selectedInputName, "Renamed Mic")
    }

    func testViewGettersUseObservedSnapshotWithoutHardwareReads() {
        let audio = MockAudioManager()
        let device = makeDevice()
        audio.inputDevices = [device]
        audio.defaultInputUID = device.uid
        let (model, _, _, _, _) = makeModel(audio: audio)
        audio.stateHandler = { _ in
            XCTFail("View getters must not query hardware")
            return AudioDeviceState(status: .unknown, canControl: false, hasSavedInputLevel: false, pendingMute: nil)
        }
        XCTAssertTrue(model.canToggleSelectedDevice)
        XCTAssertNil(model.controlUnavailableMessage)
        XCTAssertFalse(model.isInputLevelZeroWithoutSavedValue)
        XCTAssertFalse(model.isRecoveryPending)
    }
}

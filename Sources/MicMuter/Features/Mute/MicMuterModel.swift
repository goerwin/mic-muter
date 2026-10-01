import Foundation
import Observation

@MainActor
@Observable
final class MicMuterModel {
    private let audio: any AudioDeviceManaging
    private let selectionStore: any DeviceSelectionStoring
    private let settings: any SettingsStoring
    private let loginService: any LoginItemServing
    private let terminator: @MainActor () -> Void
    private let onToggleFeedback: (@MainActor (MicStatus, String) -> Void)?

    private(set) var devices: [AudioInputDevice] = []
    private(set) var defaultInputUID: String?
    private(set) var selectedDeviceUID: String?
    private(set) var selectedDeviceNameSnapshot: String?
    private(set) var status: MicStatus = .disconnected
    private(set) var errorMessage: String?
    private(set) var launchAtLoginError: String?
    private(set) var launchAtLoginStatus: LoginItemStatus = .disabled
    private(set) var showHUDOnToggle: Bool
    private var selectedAudioState: AudioDeviceState?

    init(
        audio: any AudioDeviceManaging,
        selectionStore: any DeviceSelectionStoring,
        settings: any SettingsStoring,
        loginService: any LoginItemServing,
        shortcutService: any ShortcutRegistering,
        onToggleFeedback: (@MainActor (MicStatus, String) -> Void)? = nil,
        terminator: @escaping @MainActor () -> Void
    ) {
        self.audio = audio
        self.selectionStore = selectionStore
        self.settings = settings
        self.loginService = loginService
        self.terminator = terminator
        self.onToggleFeedback = onToggleFeedback
        self.selectedDeviceUID = selectionStore.selectedDeviceUID
        self.selectedDeviceNameSnapshot = selectionStore.selectedDeviceNameSnapshot
        self.showHUDOnToggle = settings.showHUDOnToggle

        self.audio.onChange = { [weak self] in self?.refreshFromAudio() }
        self.audio.startMonitoring()
        refreshFromAudio()
        refreshLoginItemState()

        shortcutService.onToggle { [weak self] in
            Task { @MainActor [weak self] in
                self?.toggleMute()
            }
        }
    }

    var canToggleSelectedDevice: Bool {
        selectedAudioState?.canControl == true && status.canToggle
    }

    var controlUnavailableMessage: String? {
        guard let selectedAudioState, !selectedAudioState.canControl else { return nil }
        return "macOS does not expose a writable mute or input level control for this device."
    }

    var selectedDevice: AudioInputDevice? {
        if let selectedDeviceUID { return device(for: selectedDeviceUID) }
        return device(for: defaultInputUID)
    }

    var selectedInputName: String {
        selectedDevice?.name
            ?? (selectedDeviceUID == nil ? "No input device" : selectedDeviceNameSnapshot ?? "Selected microphone")
    }

    var isSelectedDeviceDisconnected: Bool {
        selectedDeviceUID != nil && selectedDevice == nil
    }

    var currentDefaultDeviceName: String {
        selectedDeviceUID == nil
            ? (selectedDevice?.name ?? "No input device")
            : (device(for: defaultInputUID)?.name ?? "No input device")
    }

    var isInputLevelZeroWithoutSavedValue: Bool {
        status == .inputSilent && selectedAudioState?.hasSavedInputLevel == false
    }

    var isRecoveryPending: Bool { selectedAudioState?.pendingMute != nil }

    var launchAtLoginEnabled: Bool {
        launchAtLoginStatus == .enabled || launchAtLoginStatus == .requiresApproval
    }

    func selectDefaultInput() {
        selectedDeviceUID = nil
        selectedDeviceNameSnapshot = nil
        selectionStore.clearSelection()
        errorMessage = nil
        refreshStatus()
    }

    func select(_ device: AudioInputDevice) {
        selectedDeviceUID = device.uid
        selectedDeviceNameSnapshot = device.name
        selectionStore.saveSelection(uid: device.uid, name: device.name)
        errorMessage = nil
        refreshStatus()
    }

    func toggleMute() {
        refreshFromAudio()
        guard canToggleSelectedDevice else { return }
        guard let selectedDevice else {
            errorMessage = "No input device is available."
            return
        }

        var didToggle = false
        do {
            try audio.setMuted(selectedAudioState?.pendingMute ?? (status != .muted), for: selectedDevice)
            errorMessage = nil
            didToggle = true
        } catch {
            errorMessage = error.localizedDescription
        }
        refreshFromAudio()
        if didToggle, showHUDOnToggle {
            onToggleFeedback?(status, selectedInputName)
        }
    }

    func setLaunchAtLogin(_ isEnabled: Bool) {
        do {
            try loginService.setEnabled(isEnabled)
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
        }
        refreshLoginItemState()
    }

    func openLoginItemSettings() {
        loginService.openSettings()
    }

    func setShowHUDOnToggle(_ isEnabled: Bool) {
        showHUDOnToggle = isEnabled
        settings.showHUDOnToggle = isEnabled
    }

    func terminate() {
        stop()
        terminator()
    }

    func stop() {
        audio.onChange = nil
        audio.stopMonitoring()
    }

    private func refreshFromAudio() {
        devices = audio.inputDevices
        defaultInputUID = audio.defaultInputUID
        if let selectedDeviceUID, let device = device(for: selectedDeviceUID),
            selectedDeviceNameSnapshot != device.name
        {
            selectedDeviceNameSnapshot = device.name
            selectionStore.saveNameSnapshot(device.name, for: selectedDeviceUID)
        }
        refreshStatus()
    }

    private func device(for uid: String?) -> AudioInputDevice? {
        guard let uid else { return nil }
        return devices.first { $0.uid == uid }
    }

    private func refreshStatus() {
        guard let selectedDevice else {
            selectedAudioState = nil
            status = .disconnected
            return
        }
        let state = audio.state(for: selectedDevice)
        selectedAudioState = state
        status = MicStatusMapper.map(state.status, canControl: state.canControl)
    }

    func refreshLoginItemState() {
        launchAtLoginStatus = loginService.status
    }
}

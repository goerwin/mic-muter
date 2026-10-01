import AppKit
import KeyboardShortcuts
import Observation
import ServiceManagement

extension KeyboardShortcuts.Name {
    static let toggleMicrophone = Self("toggleMicrophone")
}

@MainActor
@Observable
final class MicMuterModel {
    private enum DefaultsKey {
        static let selectedUID = "selectedInputDeviceUID"
        static let selectedName = "selectedInputDeviceName"
        static let showHUD = "showHUDOnToggle"
    }

    private let audio: any AudioDeviceManaging

    private(set) var devices: [AudioInputDevice] = []
    private(set) var defaultInputUID: String?
    private(set) var selectedDeviceUID: String?
    private(set) var selectedDeviceNameSnapshot: String?
    private(set) var status: MicStatus = .disconnected
    private(set) var errorMessage: String?
    private(set) var launchAtLoginError: String?
    private(set) var launchAtLoginEnabled = false
    private(set) var showHUDOnToggle: Bool

    var onToggleFeedback: ((MicStatus, String) -> Void)?

    init(audio: (any AudioDeviceManaging)? = nil) {
        self.audio = audio ?? CoreAudioDeviceManager()
        selectedDeviceUID = UserDefaults.standard.string(forKey: DefaultsKey.selectedUID)
        selectedDeviceNameSnapshot = UserDefaults.standard.string(forKey: DefaultsKey.selectedName)
        showHUDOnToggle = UserDefaults.standard.bool(forKey: DefaultsKey.showHUD)

        self.audio.onChange = { [weak self] in
            Task { @MainActor in
                self?.refreshFromAudio()
            }
        }
        self.audio.startMonitoring()
        refreshFromAudio()
        refreshLoginAtLaunchState()

        KeyboardShortcuts.onKeyUp(for: .toggleMicrophone) { [weak self] in
            Task { @MainActor [weak self] in
                self?.toggleMute()
            }
        }
    }

    var canToggleSelectedDevice: Bool {
        guard let selectedDevice, audio.canControl(selectedDevice) else { return false }
        return status.canToggle
    }

    var controlUnavailableMessage: String? {
        guard let selectedDevice, !audio.canControl(selectedDevice) else { return nil }
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
        guard status == .inputSilent, let selectedDevice else { return false }
        return !audio.hasSavedInputLevel(for: selectedDevice)
    }

    func selectDefaultInput() {
        selectedDeviceUID = nil
        selectedDeviceNameSnapshot = nil
        UserDefaults.standard.removeObject(forKey: DefaultsKey.selectedUID)
        UserDefaults.standard.removeObject(forKey: DefaultsKey.selectedName)
        errorMessage = nil
        refreshStatus()
    }

    func select(_ device: AudioInputDevice) {
        selectedDeviceUID = device.uid
        selectedDeviceNameSnapshot = device.name
        UserDefaults.standard.set(device.uid, forKey: DefaultsKey.selectedUID)
        UserDefaults.standard.set(device.name, forKey: DefaultsKey.selectedName)
        errorMessage = nil
        refreshStatus()
    }

    func toggleMute() {
        guard canToggleSelectedDevice else { return }
        guard let selectedDevice else {
            errorMessage = "No input device is available."
            return
        }

        do {
            try audio.setMuted(status != .muted, for: selectedDevice)
            errorMessage = nil
            refreshFromAudio()
            if showHUDOnToggle {
                onToggleFeedback?(status, selectedInputName)
            }
        } catch {
            errorMessage = error.localizedDescription
            refreshFromAudio()
            if showHUDOnToggle {
                onToggleFeedback?(status, selectedInputName)
            }
        }
    }

    func setLaunchAtLogin(_ isEnabled: Bool) {
        do {
            if isEnabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
        }
        refreshLoginAtLaunchState()
    }

    func setShowHUDOnToggle(_ isEnabled: Bool) {
        showHUDOnToggle = isEnabled
        UserDefaults.standard.set(isEnabled, forKey: DefaultsKey.showHUD)
    }

    func terminate() {
        NSApp.terminate(nil)
    }

    private func refreshFromAudio() {
        devices = audio.inputDevices
        defaultInputUID = audio.defaultInputUID
        if let selectedDeviceUID, let device = device(for: selectedDeviceUID) {
            selectedDeviceNameSnapshot = device.name
            UserDefaults.standard.set(device.name, forKey: DefaultsKey.selectedName)
        }
        refreshStatus()
    }

    private func device(for uid: String?) -> AudioInputDevice? {
        guard let uid else { return nil }
        return devices.first { $0.uid == uid }
    }

    private func refreshStatus() {
        guard let selectedDevice else {
            status = .disconnected
            return
        }

        switch audio.status(for: selectedDevice) {
        case .muted:
            status = .muted
        case .unmuted:
            status = .unmuted
        case .inputSilent:
            status = .inputSilent
        case .unknown:
            status = audio.canControl(selectedDevice) ? .unknown : .unsupported
        }
    }

    private func refreshLoginAtLaunchState() {
        launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
    }
}

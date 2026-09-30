import AppKit
import Foundation
import KeyboardShortcuts
import Observation
import ServiceManagement

extension KeyboardShortcuts.Name {
    static let toggleMicrophone = Self("toggleMicrophone")
}

@MainActor
@Observable
final class MicMuterModel {
    private let audio = CoreAudioDeviceManager()
    private let selectedUIDKey = "selectedInputDeviceUID"
    private let selectedNameKey = "selectedInputDeviceName"

    private(set) var devices: [AudioInputDevice] = []
    private(set) var defaultInputUID: String?
    private(set) var selectedDeviceUID: String?
    private(set) var selectedDeviceNameSnapshot: String?
    private(set) var status: MicStatus = .disconnected
    private(set) var errorMessage: String?
    private(set) var launchAtLoginError: String?
    private(set) var launchAtLoginEnabled = false

    init() {
        selectedDeviceUID = UserDefaults.standard.string(forKey: selectedUIDKey)
        selectedDeviceNameSnapshot = UserDefaults.standard.string(forKey: selectedNameKey)

        audio.onChange = { [weak self] in
            Task { @MainActor [weak self] in
                self?.refreshFromAudio()
            }
        }
        audio.startMonitoring()
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
        if let selectedDeviceUID {
            return devices.first { $0.uid == selectedDeviceUID }
        }
        guard let defaultInputUID else { return nil }
        return devices.first { $0.uid == defaultInputUID }
    }

    var selectedInputName: String {
        selectedDevice?.name
            ?? (selectedDeviceUID == nil ? "No input device" : selectedDeviceNameSnapshot ?? "Selected microphone")
    }

    var selectedInputDescription: String {
        if selectedDeviceUID == nil {
            return selectedDevice == nil ? "No default input is available" : "Default input"
        }
        return selectedDevice == nil ? "Unavailable until reconnected" : "Selected input device"
    }

    var isSelectedDeviceDisconnected: Bool {
        selectedDeviceUID != nil && selectedDevice == nil
    }

    var currentDefaultDeviceName: String {
        selectedDeviceUID == nil
            ? (selectedDevice?.name ?? "No input device")
            : (devices.first { $0.uid == defaultInputUID }?.name ?? "No input device")
    }

    var isInputLevelZeroWithoutSavedValue: Bool {
        guard status == .inputSilent, let selectedDevice else { return false }
        return !audio.hasSavedInputLevel(for: selectedDevice)
    }

    func selectDefaultInput() {
        selectedDeviceUID = nil
        selectedDeviceNameSnapshot = nil
        UserDefaults.standard.removeObject(forKey: selectedUIDKey)
        UserDefaults.standard.removeObject(forKey: selectedNameKey)
        errorMessage = nil
        refreshStatus()
    }

    func select(_ device: AudioInputDevice) {
        selectedDeviceUID = device.uid
        selectedDeviceNameSnapshot = device.name
        UserDefaults.standard.set(device.uid, forKey: selectedUIDKey)
        UserDefaults.standard.set(device.name, forKey: selectedNameKey)
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
            let shouldMute = status != .muted
            try audio.setMuted(shouldMute, for: selectedDevice)
            errorMessage = nil
            refreshFromAudio()
            status = shouldMute ? .muted : .unmuted
        } catch {
            errorMessage = error.localizedDescription
            refreshFromAudio()
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

    func terminate() {
        NSApp.terminate(nil)
    }

    private func refreshFromAudio() {
        devices = audio.inputDevices
        defaultInputUID = audio.defaultInputUID
        if let selectedDeviceUID,
            let device = devices.first(where: { $0.uid == selectedDeviceUID })
        {
            selectedDeviceNameSnapshot = device.name
            UserDefaults.standard.set(device.name, forKey: selectedNameKey)
        }
        refreshStatus()
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

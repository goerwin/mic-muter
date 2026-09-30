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
    private(set) var errorMessage: String?
    private(set) var launchAtLoginError: String?
    private(set) var launchAtLoginEnabled = false
    var showingAbout = false

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

    var status: MicStatus {
        guard let device = selectedDevice else {
            return .disconnected
        }
        let deviceStatus = audio.status(for: device)
        if deviceStatus == .unknown && !audio.canControl(device) {
            return .unsupported
        }
        switch deviceStatus {
        case .muted:
            return .muted
        case .unmuted:
            return .unmuted
        case .inputSilent:
            return .inputSilent
        case .unknown:
            return .unknown
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

    var selectedTargetTitle: String {
        if selectedDeviceUID == nil {
            return "Default Input"
        }
        if let selectedDevice {
            return selectedDevice.name
        }
        return selectedDeviceNameSnapshot ?? "Selected microphone"
    }

    var selectedTargetSubtitle: String {
        if selectedDeviceUID == nil {
            return selectedDevice?.name ?? "No default input is available"
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
    }

    func select(_ device: AudioInputDevice) {
        selectedDeviceUID = device.uid
        selectedDeviceNameSnapshot = device.name
        UserDefaults.standard.set(device.uid, forKey: selectedUIDKey)
        UserDefaults.standard.set(device.name, forKey: selectedNameKey)
        errorMessage = nil
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
        } catch {
            errorMessage = error.localizedDescription
        }
        refreshFromAudio()
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
    }

    private func refreshLoginAtLaunchState() {
        launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
    }
}

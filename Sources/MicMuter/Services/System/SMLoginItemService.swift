import ServiceManagement

@MainActor
final class SMLoginItemService: LoginItemServing {
    var status: LoginItemStatus {
        switch SMAppService.mainApp.status {
        case .enabled: .enabled
        case .notRegistered: .disabled
        case .requiresApproval: .requiresApproval
        case .notFound: .unavailable
        @unknown default: .unavailable
        }
    }

    func setEnabled(_ isEnabled: Bool) throws {
        if isEnabled {
            guard status != .enabled && status != .requiresApproval else { return }
            try SMAppService.mainApp.register()
        } else {
            guard status != .disabled else { return }
            try SMAppService.mainApp.unregister()
        }
    }

    func openSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

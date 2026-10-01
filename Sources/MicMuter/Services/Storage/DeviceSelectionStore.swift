import Foundation

/// Persists which input device the user selected.
/// `nil` uid means "follow System Default".
@MainActor
protocol DeviceSelectionStoring: AnyObject {
    var selectedDeviceUID: String? { get }
    var selectedDeviceNameSnapshot: String? { get }
    func saveSelection(uid: String, name: String)
    func saveNameSnapshot(_ name: String, for uid: String)
    func clearSelection()
}

@MainActor
final class DeviceSelectionStore: DeviceSelectionStoring {
    private enum Key {
        static let selectedUID = "selectedInputDeviceUID"
        static let selectedName = "selectedInputDeviceName"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var selectedDeviceUID: String? {
        defaults.string(forKey: Key.selectedUID)
    }

    var selectedDeviceNameSnapshot: String? {
        defaults.string(forKey: Key.selectedName)
    }

    func saveSelection(uid: String, name: String) {
        defaults.set(uid, forKey: Key.selectedUID)
        defaults.set(name, forKey: Key.selectedName)
    }

    func saveNameSnapshot(_ name: String, for uid: String) {
        guard selectedDeviceUID == uid else { return }
        defaults.set(name, forKey: Key.selectedName)
    }

    func clearSelection() {
        defaults.removeObject(forKey: Key.selectedUID)
        defaults.removeObject(forKey: Key.selectedName)
    }
}

import Foundation

@MainActor
protocol SettingsStoring: AnyObject {
    var showHUDOnToggle: Bool { get set }
}

@MainActor
final class SettingsStore: SettingsStoring {
    private enum Key {
        static let showHUD = "showHUDOnToggle"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var showHUDOnToggle: Bool {
        get { defaults.bool(forKey: Key.showHUD) }
        set { defaults.set(newValue, forKey: Key.showHUD) }
    }
}

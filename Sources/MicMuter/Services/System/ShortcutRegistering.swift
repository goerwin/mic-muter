import Foundation

/// Registers the global toggle shortcut. The production implementation
/// wraps KeyboardShortcuts; tests inject a recording double.
@MainActor
protocol ShortcutRegistering: AnyObject {
    func onToggle(_ handler: @escaping () -> Void)
}

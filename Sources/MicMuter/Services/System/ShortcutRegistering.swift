import Foundation

@MainActor
protocol ShortcutRegistering: AnyObject {
    func onToggle(_ handler: @escaping () -> Void)
}

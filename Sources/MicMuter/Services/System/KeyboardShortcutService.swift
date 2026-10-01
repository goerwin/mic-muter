import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleMicrophone = Self("toggleMicrophone")
}

@MainActor
final class KeyboardShortcutService: ShortcutRegistering {
    func onToggle(_ handler: @escaping () -> Void) {
        KeyboardShortcuts.onKeyUp(for: .toggleMicrophone, action: handler)
    }
}

import Foundation

/// Abstracts Launch at Login so `MicMuterModel` stays testable
/// without importing ServiceManagement.
@MainActor
protocol LoginItemServing: AnyObject {
    var isEnabled: Bool { get }
    func setEnabled(_ isEnabled: Bool) throws
}

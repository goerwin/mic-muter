import Foundation

enum LoginItemStatus: Equatable {
    case enabled
    case disabled
    case requiresApproval
    case unavailable
}

@MainActor
protocol LoginItemServing: AnyObject {
    var status: LoginItemStatus { get }
    func setEnabled(_ isEnabled: Bool) throws
    func openSettings()
}

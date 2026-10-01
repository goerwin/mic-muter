import Foundation

@MainActor
protocol LoginItemServing: AnyObject {
    var isEnabled: Bool { get }
    func setEnabled(_ isEnabled: Bool) throws
}

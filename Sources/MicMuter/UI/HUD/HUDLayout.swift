import AppKit

enum HUDLayout {
    static let panelSize = NSSize(width: 240, height: 200)
    static let cornerRadius: CGFloat = 24
    static let holdDuration: Duration = .milliseconds(800)
    static let fadeDuration: TimeInterval = 0.2
    static var fadeInterval: Duration { .milliseconds(Int(fadeDuration * 1000)) }
}

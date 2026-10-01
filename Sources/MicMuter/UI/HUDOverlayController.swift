import AppKit
import SwiftUI

@MainActor
final class HUDOverlayController {
    static let panelSize = NSSize(width: 240, height: 200)

    private static let fadeDuration: TimeInterval = 0.2
    private static var fadeInterval: Duration { .milliseconds(Int(fadeDuration * 1000)) }
    private static let holdDuration: Duration = .milliseconds(800)

    private let panel: NSPanel
    private var dismissalTask: Task<Void, Never>?

    init() {
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: HUDOverlayController.panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    }

    func present(status: MicStatus, deviceName: String) {
        dismissalTask?.cancel()

        panel.contentView = makeContentView(status: status, deviceName: deviceName)
        centerOnFocusedScreen()

        if panel.isVisible {
            panel.alphaValue = 1
        } else {
            panel.alphaValue = 1
            panel.orderFrontRegardless()
        }

        dismissalTask = Task { @MainActor [weak self] in
            guard let self else { return }

            try? await Task.sleep(for: HUDOverlayController.holdDuration)
            guard !Task.isCancelled else { return }

            self.setAlpha(0, animated: true)
            try? await Task.sleep(for: HUDOverlayController.fadeInterval)
            guard !Task.isCancelled else { return }

            self.dismiss()
        }
    }

    private func dismiss() {
        panel.orderOut(nil)
        panel.contentView = nil
        dismissalTask = nil
    }

    private func setAlpha(_ value: CGFloat, animated: Bool = true) {
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = HUDOverlayController.fadeDuration
                panel.animator().alphaValue = value
            }
        } else {
            panel.alphaValue = value
        }
    }

    private func makeContentView(status: MicStatus, deviceName: String) -> NSView {
        let view = NSHostingView(rootView: HUDOverlayView(status: status, deviceName: deviceName))
        view.frame = NSRect(origin: .zero, size: HUDOverlayController.panelSize)
        view.autoresizingMask = [.width, .height]
        return view
    }

    private func centerOnFocusedScreen() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let visibleFrame = screen.visibleFrame
        panel.setFrameOrigin(
            NSPoint(
                x: visibleFrame.midX - panel.frame.width / 2,
                y: visibleFrame.midY - panel.frame.height / 2
            )
        )
    }
}

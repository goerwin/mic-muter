import AppKit
import SwiftUI

private struct HUDOverlayView: View {
    let status: MicStatus
    let deviceName: String

    // `mic.slash.fill` lays out one point taller than `mic.fill`, which shifts the
    // vertically centered content by half a point between states. A fixed slot makes
    // both variants occupy identical space, so the text cannot move when toggling.
    private static let iconSlot = CGSize(width: 64, height: 76)

    // Separately, `mic.slash.fill` rasterizes one point right of and one point below
    // `mic.fill` at the same nominal size, which moves the icon itself. The slot cannot
    // correct this because it is a property of the glyph, not the layout.
    private var slashedVariantOffset: CGFloat {
        status.usesSlashSymbol ? -1 : 0
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: status.menuBarSymbol)
                .font(.system(size: 56, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
                .frame(width: Self.iconSlot.width, height: Self.iconSlot.height)
                .offset(x: slashedVariantOffset, y: slashedVariantOffset)

            VStack(spacing: 4) {
                Text(status.title)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)

                Text(deviceName)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.horizontal, 24)
        .frame(width: HUDOverlayController.panelSize.width, height: HUDOverlayController.panelSize.height)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.black.opacity(0.45))
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(status.accessibilityDescription). \(deviceName)")
    }
}

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
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        // `holdDuration` is measured from the end of the fade-in, not from the moment the
        // animation starts, so the HUD is fully opaque for the whole hold.
        dismissalTask = Task { @MainActor [weak self] in
            guard let self else { return }

            self.setAlpha(1)
            try? await Task.sleep(for: HUDOverlayController.fadeInterval)
            guard !Task.isCancelled else { return }

            try? await Task.sleep(for: HUDOverlayController.holdDuration)
            guard !Task.isCancelled else { return }

            self.setAlpha(0)
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

    private func setAlpha(_ value: CGFloat) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = HUDOverlayController.fadeDuration
            panel.animator().alphaValue = value
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

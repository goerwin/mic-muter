import AppKit
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private let model: MicMuterModel
    private let statusItem = NSStatusBar.system.statusItem(withLength: 22)
    private let popover = NSPopover()
    private var appearanceObserver: NSKeyValueObservation?

    init(model: MicMuterModel) {
        self.model = model
        super.init()

        let hosting = NSHostingController(rootView: MenuPopoverView(model: model))
        hosting.sizingOptions = .preferredContentSize
        popover.contentViewController = hosting
        popover.behavior = .transient

        statusItem.button?.target = self
        statusItem.button?.action = #selector(handleClick(_:))
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        updateButton()
        observeModel()

        appearanceObserver = NSApp.observe(\.effectiveAppearance) { [weak self] _, _ in
            Task { @MainActor in
                MenuBarIcon.invalidateCache()
                self?.updateButton()
            }
        }
    }

    @objc private func handleClick(_ sender: Any?) {
        guard let button = statusItem.button else { return }

        let isLeftClick = NSApp.currentEvent?.type == .leftMouseUp

        if isLeftClick {
            model.toggleMute()
            if popover.isShown {
                popover.performClose(sender)
            }
            return
        }

        togglePopover(from: button, sender: sender)
    }

    private func togglePopover(from button: NSStatusBarButton, sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
            return
        }

        model.refreshLoginItemState()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func observeModel() {
        withObservationTracking {
            _ = model.status
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.updateButton()
                self?.observeModel()
            }
        }
    }

    private func updateButton() {
        guard let button = statusItem.button else { return }
        button.image = MenuBarIcon.image(for: model.status)
        button.toolTip = "Mic Muter: \(model.status.title). Click to toggle, right-click for options."
        button.setAccessibilityLabel("Mic Muter. \(model.status.accessibilityDescription)")
    }
}

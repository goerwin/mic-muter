import AppKit
import SwiftUI

@MainActor
final class StatusBarController: NSObject, NSPopoverDelegate {
    private let model: MicMuterModel
    private let statusItem = NSStatusBar.system.statusItem(withLength: 22)
    private let popover = NSPopover()
    private var appearanceObserver: NSKeyValueObservation?
    private var clickOutsideMonitor: Any?

    init(model: MicMuterModel) {
        self.model = model
        super.init()

        let hosting = NSHostingController(rootView: MenuPopoverView(model: model))
        hosting.sizingOptions = .preferredContentSize
        popover.contentViewController = hosting
        popover.behavior = .transient
        popover.delegate = self

        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover(_:))
        statusItem.button?.sendAction(on: [.leftMouseUp])
        updateButton()
        observeModel()

        appearanceObserver = NSApp.observe(\.effectiveAppearance) { [weak self] _, _ in
            Task { @MainActor in
                self?.updateButton()
            }
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshIcon),
            name: NSColor.systemColorsDidChangeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        if let clickOutsideMonitor {
            NSEvent.removeMonitor(clickOutsideMonitor)
        }
    }

    func popoverDidClose(_ notification: Notification) {
        stopClickOutsideMonitor()
    }

    @objc private func refreshIcon() {
        updateButton()
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
            return
        }

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        NSApp.activate(ignoringOtherApps: true)
        startClickOutsideMonitor()
    }

    private func startClickOutsideMonitor() {
        stopClickOutsideMonitor()
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
            [weak self] _ in
            DispatchQueue.main.async {
                self?.popover.performClose(nil)
            }
        }
    }

    private func stopClickOutsideMonitor() {
        if let clickOutsideMonitor {
            NSEvent.removeMonitor(clickOutsideMonitor)
            self.clickOutsideMonitor = nil
        }
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
        let image = MenuBarIcon.image(for: model.status)
        button.image = image
        button.image?.isTemplate = image.isTemplate
        button.toolTip = "Mic Muter: \(model.status.title)"
        button.setAccessibilityLabel("Mic Muter. \(model.status.accessibilityDescription)")
    }
}

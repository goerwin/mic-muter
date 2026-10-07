import AppKit
import Sparkle
import SwiftUI

@main
struct MicMuterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: MicMuterModel?
    private var statusBar: StatusBarController?
    private let hud = HUDOverlayController()
    private let updater = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        let audio = CoreAudioDeviceManager(
            volumeStore: VolumeStore(),
            propertyAccess: CoreAudioDevicePropertyAccess()
        )
        let model = MicMuterModel(
            audio: audio,
            selectionStore: DeviceSelectionStore(),
            settings: SettingsStore(),
            loginService: SMLoginItemService(),
            shortcutService: KeyboardShortcutService(),
            onToggleFeedback: { [hud] status, deviceName in
                hud.present(status: status, deviceName: deviceName)
            },
            terminator: { NSApp.terminate(nil) }
        )
        self.model = model
        statusBar = StatusBarController(model: model) { [unowned self] in
            NSApp.activate(ignoringOtherApps: true)
            self.updater.checkForUpdates(nil)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model?.stop()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        model?.refreshLoginItemState()
    }
}

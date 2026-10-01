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

    func applicationDidFinishLaunching(_ notification: Notification) {
        let model = MicMuterModel()
        self.model = model
        statusBar = StatusBarController(model: model)
        model.onToggleFeedback = { [hud] status, deviceName in
            hud.present(status: status, deviceName: deviceName)
        }
    }
}

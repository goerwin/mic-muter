import SwiftUI

@main
struct MicMuterApp: App {
    @State private var model = MicMuterModel()

    var body: some Scene {
        MenuBarExtra {
            MenuPopoverView(model: model)
        } label: {
            MenuBarStatusItem(status: model.status)
        }
        .menuBarExtraStyle(.window)
    }
}

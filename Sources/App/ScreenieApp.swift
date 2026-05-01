import SwiftUI

@main
struct ScreenieApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .frame(width: 420, height: 320)
        }
    }
}

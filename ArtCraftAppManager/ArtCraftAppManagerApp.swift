import AppKit
import SwiftUI

@main
struct ArtCraftAppManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel()

    var body: some Scene {
        Window("ArtCraft Application Manager", id: "main") {
            MainView().environment(model)
        }
        .defaultLaunchBehavior(AppLifecyclePolicy.showsWindowOnLaunch(startedByLoginItem: model.startedByLoginItem) ? .presented : .suppressed)

        Settings {
            SettingsView().environment(model)
        }

        MenuBarExtra(isInserted: Binding(get: { AppLifecyclePolicy.hasMenuBarItem(launchAtLogin: model.launchAtLogin) }, set: { _ in })) {
            MenuBarContent().environment(model)
        } label: {
            let count = model.menuBarModel.badgeCount
            Image(systemName: count > 0 ? "arrow.down.circle.fill" : "arrow.down.circle")
            if count > 0 { Text("\(count)") }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        AppLifecyclePolicy.quitsWhenLastWindowCloses(launchAtLogin: UserDefaults.standard.bool(forKey: "launchAtLogin"))
    }
}

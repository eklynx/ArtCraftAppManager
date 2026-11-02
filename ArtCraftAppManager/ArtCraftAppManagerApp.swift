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
        .commands {
            CommandGroup(replacing: .appInfo) {  // REQ-WIN-28
                Button("About ArtCraft Application Manager") { AboutContent.showAboutPanel() }
            }
        }

        Settings {
            SettingsView().environment(model)
        }
        .defaultSize(width: 520, height: 940)  // open tall enough to show every app (REQ-SET-13)

        MenuBarExtra(isInserted: Binding(get: { AppLifecyclePolicy.hasMenuBarItem(launchAtLogin: model.launchAtLogin) }, set: { _ in })) {
            MenuBarContent().environment(model)
        } label: {
            let count = model.menuBarModel.badgeCount
            Image("MenuBarIcon").renderingMode(.original)  // REQ-WIN-19/26: full-colour icon, not a template
            if count > 0 { Text("\(count)") }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        AppLifecyclePolicy.quitsWhenLastWindowCloses(launchAtLogin: UserDefaults.standard.bool(forKey: "launchAtLogin"))
    }
}

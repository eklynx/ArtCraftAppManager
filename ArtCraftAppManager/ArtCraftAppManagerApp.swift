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
                Button("Check for Updates…") { model.managerUpdater.checkForUpdates() }  // REQ-UPD-3
            }
        }

        Settings {
            SettingsView().environment(model)
        }
        .defaultSize(width: 520, height: 940)  // open tall enough to show every app (REQ-SET-13)

        MenuBarExtra(isInserted: Binding(get: { AppLifecyclePolicy.hasMenuBarItem(launchAtLogin: model.launchAtLogin) }, set: { _ in })) {
            MenuBarContent().environment(model)
        } label: {
            MenuBarLabel(model: model)
        }
    }
}

/// The menu bar icon (REQ-WIN-19/26: full-colour, not a template). Always alive while the item is shown, so it also opens the
/// main window when a clicked notification asks for it (REQ-WIN-29: an accessory app has no window to reveal otherwise).
private struct MenuBarLabel: View {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let count = model.menuBarModel.badgeCount
        HStack {
            Image("MenuBarIcon").renderingMode(.original)
            if count > 0 { Text("\(count)") }
        }
        .onChange(of: model.openMainRequest) {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// REQ-WIN-29. Not created in test launches, which must not change the Dock.
    private var dock: DockVisibilityController?

    func applicationWillFinishLaunching(_ notification: Notification) {
        let isTest = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("-uitest") }
        guard !isTest else { return }
        let controller = DockVisibilityController(policy: SystemActivationPolicySetter(),
                                                  launchAtLogin: { UserDefaults.standard.bool(forKey: "launchAtLogin") })
        dock = controller
        controller.start(startedByLoginItem: AppModel.launchedAsLoginItem())
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        AppLifecyclePolicy.quitsWhenLastWindowCloses(launchAtLogin: UserDefaults.standard.bool(forKey: "launchAtLogin"))
    }
}

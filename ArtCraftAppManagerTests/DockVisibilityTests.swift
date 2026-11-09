import Foundation
import Testing
@testable import ArtCraftAppManager

// docs/specs/04-main-window.md (REQ-WIN-29): Dock icon follows the windows when the Manager lives in the menu bar.
struct DockVisibilityTests {
    @Test("REQ-WIN-29 the Dock icon is hidden only with Launch at login on and no open window")
    func policy() {
        #expect(AppLifecyclePolicy.hidesDockIcon(launchAtLogin: true, hasVisibleWindows: false))
        #expect(!AppLifecyclePolicy.hidesDockIcon(launchAtLogin: true, hasVisibleWindows: true))
        #expect(!AppLifecyclePolicy.hidesDockIcon(launchAtLogin: false, hasVisibleWindows: false))
        #expect(!AppLifecyclePolicy.hidesDockIcon(launchAtLogin: false, hasVisibleWindows: true))
    }

    @Test("REQ-WIN-29 a login-item launch starts without a Dock icon only when Launch at login is on")
    func launchState() {
        #expect(!AppLifecyclePolicy.startsWithDockIcon(startedByLoginItem: true, launchAtLogin: true))
        #expect(AppLifecyclePolicy.startsWithDockIcon(startedByLoginItem: true, launchAtLogin: false))
        #expect(AppLifecyclePolicy.startsWithDockIcon(startedByLoginItem: false, launchAtLogin: true))
        #expect(AppLifecyclePolicy.startsWithDockIcon(startedByLoginItem: false, launchAtLogin: false))
    }

    @MainActor
    @Test("REQ-WIN-29 the controller hides the icon when the last window closes and shows it when one opens")
    func controllerFollowsWindows() {
        let policy = FakeActivationPolicy()
        var windows = 1
        var launchAtLogin = true
        let controller = DockVisibilityController(policy: policy, launchAtLogin: { launchAtLogin }, visibleWindowCount: { windows })
        controller.update()
        #expect(policy.dockIconVisible == true)
        windows = 0
        controller.update()
        #expect(policy.dockIconVisible == false)
        windows = 1  // Settings or the main window opens
        controller.update()
        #expect(policy.dockIconVisible == true)
        windows = 0
        launchAtLogin = false  // no menu bar item: keep the icon (the app quits instead)
        controller.update()
        #expect(policy.dockIconVisible == true)
    }

    @MainActor
    @Test("REQ-WIN-29 a clicked notification asks for the main window to open")
    func notificationOpensWindow() {
        let model = AppModel(arguments: ["-uitest"])
        let before = model.openMainRequest
        model.reveal("gridcraft")
        #expect(model.openMainRequest == before + 1)
    }
}

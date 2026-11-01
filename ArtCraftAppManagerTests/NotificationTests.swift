import Foundation
import Testing
@testable import ArtCraftAppManager

// docs/specs/06-notifications.md

struct NotificationMatrixTests {
    @Test("REQ-NOT-4 behaviour matrix", arguments: [
        (false, false, false, UpdateAction.notifyAvailable),
        (false, false, true, UpdateAction.notifyAvailable),
        (true, false, false, UpdateAction.downloadThenNotifyReady),
        (true, false, true, UpdateAction.downloadThenNotifyReady),
        (true, true, false, UpdateAction.downloadAndInstall),
        (true, true, true, UpdateAction.downloadThenInstallWhenAppQuits),
    ])
    func matrix(download: Bool, install: Bool, running: Bool, expected: UpdateAction) {
        #expect(UpdatePlanner.action(autoDownload: download, autoInstall: install, appRunning: running) == expected)
    }
}

struct NotificationServiceTests {
    let app = makeApp()

    private func service(allowed: Bool = true) -> (UpdateNotificationService, FakeNotifier, InMemoryStateStore) {
        let notifier = FakeNotifier(); notifier.allowed = allowed
        let state = InMemoryStateStore()
        return (UpdateNotificationService(notifier: notifier, state: state), notifier, state)
    }

    @Test("REQ-NOT-1 / REQ-NOT-8 permission is requested and posts go through the UpdateNotifying seam")
    func posts() async {
        let (service, notifier, _) = service()
        await service.start()
        #expect(await service.deliver(.updateAvailable, app: app, version: "0.15.0") == .posted)
        #expect(notifier.posted.count == 1 && notifier.posted[0].0 == .updateAvailable)
    }

    @Test("REQ-NOT-1 when permission is denied, notifications degrade to a badge")
    func denied() async {
        let (service, notifier, _) = service(allowed: false)
        await service.start()
        #expect(await service.deliver(.updateAvailable, app: app, version: "0.15.0") == .badgeOnly)
        #expect(notifier.posted.isEmpty)
    }

    @Test("REQ-NOT-3 at most one notification per app, version and kind — across restarts")
    func dedupes() async {
        let (service, notifier, state) = service()
        await service.start()
        _ = await service.deliver(.updateReady, app: app, version: "0.15.0")
        #expect(await service.deliver(.updateReady, app: app, version: "0.15.0") == .suppressedDuplicate)
        #expect(await service.deliver(.updateReady, app: app, version: "0.16.0") == .posted)
        #expect(await service.deliver(.updateAvailable, app: app, version: "0.15.0") == .posted)
        let restarted = UpdateNotificationService(notifier: notifier, state: state)
        await restarted.start()
        #expect(await restarted.deliver(.updateReady, app: app, version: "0.15.0") == .suppressedDuplicate)
    }

    @Test("REQ-NOT-2 clicking a notification brings that app's row into view")
    func click() {
        let (service, _, _) = service()
        #expect(service.rowToReveal(forClickedNotificationOf: "gridcraft") == "gridcraft")
    }
}

struct AutoUpdateTests {
    let app = makeApp()
    let release = makeRelease("0.15.0")

    private func rig(running: Bool) -> (AutoUpdateController, FakeInstaller, FakeNotifier, FakeReporter, InstalledApp) {
        let installed = makeInstalled(app, url: URL(fileURLWithPath: "/Volumes/X/GridCraft.app"), version: "0.14.0")
        let installer = FakeInstaller(result: installed)
        let notifier = FakeNotifier()
        let locator = FakeLocator(); locator.running = running
        let reporter = FakeReporter()
        let controller = AutoUpdateController(installer: installer, locator: locator,
                                              notifications: UpdateNotificationService(notifier: notifier, state: InMemoryStateStore()),
                                              quitObserver: FakeQuitObserver(), reporter: reporter)
        return (controller, installer, notifier, reporter, installed)
    }

    @Test("REQ-NOT-4 / REQ-NOT-5 auto install of a closed app installs and sends updateInstalled")
    func closedApp() async {
        let (controller, installer, notifier, _, installed) = rig(running: false)
        var policy = UpdatePolicy(); policy.setAutoInstall(true)
        await controller.handleNewRelease(app: app, installed: installed, release: release, policy: policy, windowVisible: true)
        #expect(installer.updates == 1)
        #expect(notifier.posted.map(\.0) == [.updateInstalled])
    }

    @Test("REQ-NOT-5 a running app gets one 'running' notification and is installed after it quits")
    func runningApp() async {
        let (controller, installer, notifier, _, installed) = rig(running: true)
        var policy = UpdatePolicy(); policy.setAutoInstall(true)
        await controller.handleNewRelease(app: app, installed: installed, release: release, policy: policy, windowVisible: true)
        #expect(notifier.posted.map(\.0).first == .updateReadyAppRunning)
        #expect(installer.updates == 1)  // after the fake observer reports the quit
        #expect(notifier.posted.map(\.0).last == .updateInstalled)
    }

    @Test("REQ-NOT-6 an automatic failure goes to the status line and, with the window hidden, the menu bar badge")
    func failureReporting() async {
        let (controller, installer, _, reporter, installed) = rig(running: false)
        installer.failure = .swapFailed(app: "GridCraft")
        var policy = UpdatePolicy(); policy.setAutoInstall(true)
        await controller.handleNewRelease(app: app, installed: installed, release: release, policy: policy, windowVisible: false)
        #expect(reporter.errors == [.swapFailed(app: "GridCraft")])
        #expect(reporter.badge)
    }

    @Test("REQ-NOT-7 scheduled checks only run while the Manager runs: a 6-hour in-process interval, no background agent")
    func noBackgroundAgent() {
        #expect(UpdateCoordinator.interval == 21_600)
        let plist = try? String(contentsOf: Repo.pbxproj, encoding: .utf8)
        #expect(plist?.contains("LaunchAgent") == false)
    }
}

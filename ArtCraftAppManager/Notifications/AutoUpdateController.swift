import Foundation

final class AutoUpdateController {
    private let installer: InstallationManaging
    private let locator: InstalledAppLocating
    private let notifications: UpdateNotificationService
    private let quitObserver: QuitObserving
    private let reporter: StatusReporting

    init(installer: InstallationManaging, locator: InstalledAppLocating, notifications: UpdateNotificationService,
         quitObserver: QuitObserving, reporter: StatusReporting) {
        self.installer = installer
        self.locator = locator
        self.notifications = notifications
        self.quitObserver = quitObserver
        self.reporter = reporter
    }

    /// Applies the REQ-NOT-4 matrix for one App with a newer release (REQ-NOT-5, REQ-NOT-6).
    func handleNewRelease(app: RegistryApp, installed: InstalledApp, release: Release, policy: UpdatePolicy, windowVisible: Bool) async {
        let version = release.version.description
        let action = UpdatePlanner.action(autoDownload: policy.autoDownload, autoInstall: policy.autoInstall,
                                          appRunning: locator.isRunning(installed))
        do {
            switch action {
            case .notifyAvailable:
                _ = await notifications.deliver(.updateAvailable, app: app, version: version)
            case .downloadThenNotifyReady:
                try await installer.download(release, app: app) { _ in }
                _ = await notifications.deliver(.updateReady, app: app, version: version)
            case .downloadAndInstall:
                _ = try await installer.update(installed, app: app, to: release) { _ in }
                _ = await notifications.deliver(.updateInstalled, app: app, version: version)
            case .downloadThenInstallWhenAppQuits:
                try await installer.download(release, app: app) { _ in }
                _ = await notifications.deliver(.updateReadyAppRunning, app: app, version: version)
                await quitObserver.waitForQuit(of: installed)
                _ = try await installer.update(installed, app: app, to: release) { _ in }
                _ = await notifications.deliver(.updateInstalled, app: app, version: version)
            }
        } catch let error as ManagerError {
            reporter.show(error)
            if !windowVisible { reporter.setAttentionBadge(true) }
        } catch {
            // Cancellation or an unexpected error: nothing to show.
        }
    }
}

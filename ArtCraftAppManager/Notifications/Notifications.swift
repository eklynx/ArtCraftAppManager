import Foundation

enum NotificationKind: String, Equatable {
    case updateAvailable, updateReady, updateReadyAppRunning, updateInstalled
}

/// Posts user notifications.
///
/// **Happy path:** `requestAuthorization` returns whether notifications are allowed; `post` delivers one.
/// **Errors:** none thrown; a denied permission is reported by `requestAuthorization() == false`.
protocol UpdateNotifying {
    func requestAuthorization() async -> Bool
    func post(kind: NotificationKind, appId: String, appName: String, version: String) async
}

/// Watches for an App quitting (`NSWorkspace` in production, REQ-NOT-5).
///
/// **Happy path:** `waitForQuit` returns once the App is no longer running.
/// **Errors:** none thrown; cancelling the awaiting task ends the wait.
protocol QuitObserving {
    /// Suspends until the App is no longer running.
    func waitForQuit(of installed: InstalledApp) async
}

/// Receives status/attention feedback for UI that may be hidden.
///
/// **Happy path:** `show` puts the error on the status line; `setAttentionBadge` toggles the menu bar badge.
/// **Errors:** none thrown.
protocol StatusReporting: AnyObject {
    func show(_ error: ManagerError)
    func setAttentionBadge(_ on: Bool)
}

enum UpdateAction: Equatable {
    case notifyAvailable
    case downloadThenNotifyReady
    case downloadAndInstall
    case downloadThenInstallWhenAppQuits
}

enum UpdatePlanner {
    /// The behaviour matrix of REQ-NOT-4 for an installed App that has a newer Release.
    static func action(autoDownload: Bool, autoInstall: Bool, appRunning: Bool) -> UpdateAction {
        guard autoDownload else { return .notifyAvailable }
        guard autoInstall else { return .downloadThenNotifyReady }
        return appRunning ? .downloadThenInstallWhenAppQuits : .downloadAndInstall
    }
}

enum DeliveryOutcome: Equatable {
    case posted, suppressedDuplicate, badgeOnly
}

final class UpdateNotificationService {
    private let notifier: UpdateNotifying
    private let state: ManagerStateStoring
    private var allowed = true

    init(notifier: UpdateNotifying, state: ManagerStateStoring) {
        self.notifier = notifier
        self.state = state
    }

    /// Requests permission (REQ-NOT-1).
    func start() async {
        allowed = await notifier.requestAuthorization()
    }

    /// Posts at most once per App, version and kind (REQ-NOT-3); degrades to a badge when denied (REQ-NOT-1).
    func deliver(_ kind: NotificationKind, app: RegistryApp, version: String) async -> DeliveryOutcome {
        let key = "\(kind.rawValue)|\(app.id)|\(version)"
        var current = state.load()
        guard current.notified.insert(key).inserted else { return .suppressedDuplicate }
        try? state.save(current)
        guard allowed else { return .badgeOnly }
        await notifier.post(kind: kind, appId: app.id, appName: app.displayName, version: version)
        return .posted
    }

    /// The App id whose row a clicked notification should bring into view (REQ-NOT-2).
    func rowToReveal(forClickedNotificationOf appId: String) -> String? {
        appId.isEmpty ? nil : appId
    }
}

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

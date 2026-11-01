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
        // Red: not implemented yet.
        .notifyAvailable
    }
}

enum DeliveryOutcome: Equatable {
    case posted, suppressedDuplicate, badgeOnly
}

final class UpdateNotificationService {
    private let notifier: UpdateNotifying
    private let state: ManagerStateStoring

    init(notifier: UpdateNotifying, state: ManagerStateStoring) {
        self.notifier = notifier
        self.state = state
    }

    /// Requests permission (REQ-NOT-1).
    func start() async {
        // Red: not implemented yet.
    }

    /// Posts at most once per App, version and kind (REQ-NOT-3); degrades to a badge when denied (REQ-NOT-1).
    func deliver(_ kind: NotificationKind, app: RegistryApp, version: String) async -> DeliveryOutcome {
        // Red: not implemented yet.
        .suppressedDuplicate
    }

    /// The App id whose row a clicked notification should bring into view (REQ-NOT-2).
    func rowToReveal(forClickedNotificationOf appId: String) -> String? {
        // Red: not implemented yet.
        nil
    }
}

final class AutoUpdateController {
    init(installer: InstallationManaging, locator: InstalledAppLocating, notifications: UpdateNotificationService,
         quitObserver: QuitObserving, reporter: StatusReporting) {}

    /// Applies the REQ-NOT-4 matrix for one App with a newer release (REQ-NOT-5, REQ-NOT-6).
    func handleNewRelease(app: RegistryApp, installed: InstalledApp, release: Release, policy: UpdatePolicy, windowVisible: Bool) async {
        // Red: not implemented yet.
    }
}

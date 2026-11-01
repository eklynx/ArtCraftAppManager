// SOURCE OF TRUTH (for humans and AI agents): the `Notifications` namespace contract.
// Types: UpdateNotifying, QuitObserving, StatusReporting, NotificationKind, UpdateAction, DeliveryOutcome.
// Implementations: UpdatePlanner.swift, UpdateNotificationService.swift, AutoUpdateController.swift, UserNotificationNotifier.swift, WorkspaceQuitObserver.swift.
// Read the doc comments on each protocol (happy path + errors) before calling into this namespace,
// and the governing spec: docs/specs/06-notifications.md. Other namespaces MUST go through these protocols.

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

enum DeliveryOutcome: Equatable {
    case posted, suppressedDuplicate, badgeOnly
}

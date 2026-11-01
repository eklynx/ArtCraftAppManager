import AppKit
import Foundation
import UserNotifications

/// UNUserNotificationCenter-backed notifier; clicks are reported to `onClick` with the App id (REQ-NOT-2).
final class UserNotificationNotifier: NSObject, UpdateNotifying, UNUserNotificationCenterDelegate {
    var onClick: ((String) -> Void)?
    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
    }

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func post(kind: NotificationKind, appId: String, appName: String, version: String) async {
        let content = UNMutableNotificationContent()
        switch kind {
        case .updateAvailable:
            content.title = "\(appName) \(version) is available"
            content.body = "Open ArtCraft Application Manager to update."
        case .updateReady:
            content.title = "\(appName) \(version) is ready to install"
            content.body = "The update has been downloaded."
        case .updateReadyAppRunning:
            content.title = "\(appName) \(version) is ready to install"
            content.body = "\(appName) is running. It will be updated when you quit it."
        case .updateInstalled:
            content.title = "\(appName) was updated to \(version)"
        }
        content.userInfo = ["appId": appId]
        let request = UNNotificationRequest(identifier: "\(kind.rawValue)-\(appId)-\(version)", content: content, trigger: nil)
        try? await center.add(request)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let id = response.notification.request.content.userInfo["appId"] as? String else { return }
        await MainActor.run {
            NSApp.activate(ignoringOtherApps: true)
            onClick?(id)
        }
    }
}

/// Waits for an App to quit using NSWorkspace termination notifications (REQ-NOT-5).
struct WorkspaceQuitObserver: QuitObserving {
    func waitForQuit(of installed: InstalledApp) async {
        func isRunning() -> Bool { SystemAppLookup.runningBundleIDs().contains(installed.bundleId) }
        guard isRunning() else { return }
        for await _ in NSWorkspace.shared.notificationCenter.notifications(named: NSWorkspace.didTerminateApplicationNotification) {
            if Task.isCancelled || !isRunning() { return }
        }
    }
}

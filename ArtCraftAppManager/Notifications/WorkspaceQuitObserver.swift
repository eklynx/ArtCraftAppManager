import AppKit
import Foundation
import UserNotifications

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

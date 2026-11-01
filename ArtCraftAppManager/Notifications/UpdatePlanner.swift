import Foundation

enum UpdatePlanner {
    /// The behaviour matrix of REQ-NOT-4 for an installed App that has a newer Release.
    static func action(autoDownload: Bool, autoInstall: Bool, appRunning: Bool) -> UpdateAction {
        guard autoDownload else { return .notifyAvailable }
        guard autoInstall else { return .downloadThenNotifyReady }
        return appRunning ? .downloadThenInstallWhenAppQuits : .downloadAndInstall
    }
}

import Foundation
import Sparkle

/// Sparkle-backed Manager updater (REQ-UPD-1). The Feed URL and public key come from Info.plist (`SUFeedURL`, `SUPublicEDKey`).
@MainActor
final class SparkleManagerUpdater: NSObject, ManagerUpdating, SPUUpdaterDelegate {
    private var controller: SPUStandardUpdaterController!
    var channel: ManagerUpdateChannel

    var canCheckForUpdates: Bool { controller.updater.canCheckForUpdates }
    var automaticallyChecks: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    init(automaticallyChecks: Bool, channel: ManagerUpdateChannel) {
        self.channel = channel
        super.init()
        controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
        controller.updater.automaticallyChecksForUpdates = automaticallyChecks
        controller.startUpdater()
    }

    func checkForUpdates() { controller.checkForUpdates(nil) }

    nonisolated func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        MainActor.assumeIsolated { channel.sparkleChannels }
    }
}

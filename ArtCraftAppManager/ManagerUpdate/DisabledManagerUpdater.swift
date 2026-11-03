import Foundation

/// Does nothing. Used in Debug builds and test runs so they never touch the network or show update dialogs (REQ-UPD-6).
@MainActor
final class DisabledManagerUpdater: ManagerUpdating {
    var canCheckForUpdates: Bool { false }
    var automaticallyChecks: Bool
    var channel: ManagerUpdateChannel
    private(set) var checkCount = 0

    init(automaticallyChecks: Bool = true, channel: ManagerUpdateChannel = .release) {
        self.automaticallyChecks = automaticallyChecks
        self.channel = channel
    }

    func checkForUpdates() { checkCount += 1 }
}

import CryptoKit
import Foundation

/// Run / Open Location actions (REQ-INS-15).
struct AppActions {
    var launcher: AppLaunching

    func run(_ installed: InstalledApp) { launcher.launch(installed.url) }
    func openLocation(_ installed: InstalledApp) { launcher.reveal(installed.url) }
}

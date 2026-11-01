import Foundation

/// Coupling between the two auto toggles (REQ-SET-4).
struct UpdatePolicy: Equatable {
    var autoDownload = false
    var autoInstall = false
    /// True while Auto Install forces Auto Download on.
    var isAutoDownloadLocked: Bool { autoInstall }

    mutating func setAutoInstall(_ on: Bool) {
        autoInstall = on
        if on { autoDownload = true }
    }

    mutating func setAutoDownload(_ on: Bool) {
        guard !isAutoDownloadLocked else { return }
        autoDownload = on
    }
}

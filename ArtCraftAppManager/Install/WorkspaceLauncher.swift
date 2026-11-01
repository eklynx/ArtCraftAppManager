import AppKit
import Foundation

/// Launches and reveals Apps through NSWorkspace.
struct WorkspaceLauncher: AppLaunching {
    func launch(_ url: URL) {
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
    func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

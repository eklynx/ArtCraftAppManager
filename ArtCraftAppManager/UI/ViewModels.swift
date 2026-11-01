import Foundation

enum RowButton: Equatable, Hashable {
    case run, openLocation, uninstall, update, install, cancel
}

/// Presentation logic for one list row (docs/specs/04-main-window.md).
struct AppRowModel {
    var name: String
    var installed: InstalledApp?
    var available: Release?
    var isRunning = false
    /// 0...1 while downloading/installing, nil otherwise.
    var progress: Double?
    var inRegistry = true
    var hidesUpdateWhenCurrent = true

    var versionText: String { "" /* Red: not implemented yet. */ }
    var pathText: String { "" /* Red: not implemented yet. */ }
    var visibleButtons: [RowButton] { [] /* Red: not implemented yet. */ }
    var enabledButtons: Set<RowButton> { [] /* Red: not implemented yet. */ }
    var showsRunningLabel: Bool { false /* Red: not implemented yet. */ }
    var showsProgressBar: Bool { false /* Red: not implemented yet. */ }
    var registryNote: String? { nil /* Red: not implemented yet. */ }
    func tooltip(for button: RowButton) -> String? { nil /* Red: not implemented yet. */ }
}

struct MenuBarModel {
    struct Entry: Equatable { var appId: String; var name: String; var installed: AppVersion; var available: AppVersion }
    var entries: [Entry]

    var badgeCount: Int { 0 /* Red: not implemented yet. */ }
    var lines: [String] { [] /* Red: not implemented yet. */ }
    static var fixedItems: [String] { [] /* Red: not implemented yet. */ }
    func rowToScroll(forLine index: Int) -> String? { nil /* Red: not implemented yet. */ }
}

struct StatusLine: Equatable {
    private(set) var text: String?

    mutating func show(_ error: ManagerError) { /* Red: not implemented yet. */ }
    /// Cleared on the next successful operation (REQ-WIN-7).
    mutating func operationSucceeded() { /* Red: not implemented yet. */ }
    mutating func tapped() { /* Red: not implemented yet. */ }
}

final class MainWindowModel {
    private(set) var rowIds: [String] = []
    private(set) var isChecking = false
    private(set) var status = StatusLine()
    var showsEmptyState: Bool { false /* Red: not implemented yet. */ }

    /// Rows: enabled registry apps in registry order, then installed apps removed from the registry (REQ-WIN-1).
    func setRows(registry: AppRegistry, enabled: Set<String>, removedFromRegistry: [String]) {
        // Red: not implemented yet.
    }

    /// Runs a check; spinner while it runs (REQ-WIN-5); on failure keeps rows and shows the error (REQ-WIN-8).
    func refresh(using check: () async throws -> Void) async {
        // Red: not implemented yet.
    }
}

enum AppLifecyclePolicy {
    /// REQ-WIN-10
    static func quitsWhenLastWindowCloses(launchAtLogin: Bool) -> Bool { true /* Red: not implemented yet. */ }
    /// REQ-WIN-11
    static func showsWindowOnLaunch(startedByLoginItem: Bool) -> Bool { true /* Red: not implemented yet. */ }
    /// REQ-WIN-9
    static func hasMenuBarItem(launchAtLogin: Bool) -> Bool { true /* Red: not implemented yet. */ }
}

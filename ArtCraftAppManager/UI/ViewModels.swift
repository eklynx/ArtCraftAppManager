// SOURCE OF TRUTH (for humans and AI agents): the `UI` namespace contract.
// Types: AppRowModel, MenuBarModel, StatusLine, MainWindowModel, AppLifecyclePolicy.
// Read the doc comments on each protocol (happy path + errors) before calling into this namespace,
// and the governing spec: docs/specs/04-main-window.md. Other namespaces MUST go through these protocols.

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

    private var updateAvailable: Bool {
        guard inRegistry, let installed, let available else { return false }
        return available.version > installed.version
    }

    var versionText: String {
        guard let installed else { return "" }
        let base = "Ver: \(installed.version)"
        return updateAvailable ? "\(base) → \(available!.version)" : base
    }

    var pathText: String {
        installed.map { $0.url.deletingLastPathComponent().path } ?? "Not installed"
    }

    var visibleButtons: [RowButton] {
        if let progress { return progress < 1 ? [.cancel] : [] }
        guard installed != nil else { return [.install] }
        var buttons: [RowButton] = [.uninstall]
        if updateAvailable || (inRegistry && !hidesUpdateWhenCurrent) { buttons.append(.update) }
        buttons += [.run, .openLocation]
        return buttons
    }

    var enabledButtons: Set<RowButton> {
        if progress != nil { return Set(visibleButtons) }
        guard installed != nil else { return [.install] }
        var enabled: Set<RowButton> = [.run, .openLocation]
        if !isRunning {
            enabled.insert(.uninstall)
            if updateAvailable { enabled.insert(.update) }
        }
        return enabled
    }

    var showsRunningLabel: Bool { isRunning && installed != nil }
    var showsProgressBar: Bool { progress != nil }
    var registryNote: String? { inRegistry ? nil : "No longer in registry" }

    func tooltip(for button: RowButton) -> String? {
        guard isRunning else { return nil }
        switch button {
        case .update: return "Quit \(name) to update"
        case .uninstall: return "Quit \(name) to uninstall"
        default: return nil
        }
    }
}

struct MenuBarModel {
    struct Entry: Equatable { var appId: String; var name: String; var installed: AppVersion; var available: AppVersion }
    var entries: [Entry]

    var badgeCount: Int { entries.count }
    var lines: [String] { entries.map { "\($0.name) \($0.installed) → \($0.available)" } }
    static var fixedItems: [String] { ["Check Now", "Open Manager", "Quit"] }

    func rowToScroll(forLine index: Int) -> String? {
        entries.indices.contains(index) ? entries[index].appId : nil
    }
}

struct StatusLine: Equatable {
    private(set) var text: String?

    mutating func show(_ error: ManagerError) {
        if let message = error.statusText { text = message }
    }

    /// Cleared on the next successful operation (REQ-WIN-7).
    mutating func operationSucceeded() { text = nil }
    mutating func tapped() { text = nil }
}

final class MainWindowModel {
    private(set) var rowIds: [String] = []
    private(set) var isChecking = false
    private(set) var status = StatusLine()
    var showsEmptyState: Bool { rowIds.isEmpty }

    /// Rows: enabled registry apps in registry order, then installed apps removed from the registry (REQ-WIN-1).
    func setRows(registry: AppRegistry, enabled: Set<String>, removedFromRegistry: [String]) {
        rowIds = registry.apps.map(\.id).filter(enabled.contains) + removedFromRegistry
    }

    /// Runs a check; spinner while it runs (REQ-WIN-5); on failure keeps rows and shows the error (REQ-WIN-8).
    func refresh(using check: () async throws -> Void) async {
        isChecking = true
        defer { isChecking = false }
        do {
            try await check()
            status.operationSucceeded()
        } catch let error as ManagerError {
            status.show(error)
        } catch {}
    }
}

enum AppLifecyclePolicy {
    /// REQ-WIN-10
    static func quitsWhenLastWindowCloses(launchAtLogin: Bool) -> Bool { !launchAtLogin }
    /// REQ-WIN-11
    static func showsWindowOnLaunch(startedByLoginItem: Bool) -> Bool { !startedByLoginItem }
    /// REQ-WIN-9
    static func hasMenuBarItem(launchAtLogin: Bool) -> Bool { launchAtLogin }
}

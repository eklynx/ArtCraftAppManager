// SOURCE OF TRUTH (for humans and AI agents): the `Detection` namespace contract.
// Types: InstalledApp, InstalledAppLocating, RunningAppsObserving, ResolvedInstall.
// Implementations: InstallResolver.swift, DiskAppLocator.swift, WorkspaceRunningAppsObserver.swift, RunningStateRefresher.swift.
// Read the doc comments on each protocol (happy path + errors) before calling into this namespace,
// and the governing spec: docs/specs/03-install-update.md. Other namespaces MUST go through these protocols.

import Foundation

struct InstalledApp: Equatable {
    var appId: String
    var bundleId: String
    var url: URL
    var version: AppVersion
}

/// Finds installed copies of Apps and reports whether they are running.
///
/// **Happy path:** `installedCopies` returns every copy of the App found on local volumes
/// (by bundle ID, falling back to recorded path / known folders).
/// **Errors:** none thrown; an unreadable bundle is skipped.
protocol InstalledAppLocating {
    func installedCopies(of app: RegistryApp) -> [InstalledApp]
    func isRunning(_ installed: InstalledApp) -> Bool
}

/// Reports when any application on the Mac launches or quits, so "running" state can be re-read (REQ-WIN-27).
///
/// **Happy path:** `changes()` returns a stream that yields once per launch or quit event, for as long as the
/// consumer iterates it. The event carries no payload: re-ask `InstalledAppLocating.isRunning` for the truth.
/// **Errors:** none thrown. The stream ends only when the consumer stops iterating (cancels its task).
protocol RunningAppsObserving {
    func changes() -> AsyncStream<Void>
}

struct ResolvedInstall: Equatable {
    var shown: InstalledApp
    var others: [InstalledApp]
}

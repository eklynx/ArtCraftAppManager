// SOURCE OF TRUTH (for humans and AI agents): the `Detection` namespace contract.
// Types: InstalledApp, InstalledAppLocating, ResolvedInstall.
// Implementations: InstallResolver.swift, DiskAppLocator.swift.
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

struct ResolvedInstall: Equatable {
    var shown: InstalledApp
    var others: [InstalledApp]
}

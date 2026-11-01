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

enum InstallResolver {
    /// Chooses which copy the row shows: the recorded path, else the highest version (REQ-INS-3).
    static func resolve(copies: [InstalledApp], recordedPath: URL?) -> ResolvedInstall? {
        // Red: not implemented yet.
        nil
    }
}

/// Filesystem-backed locator (REQ-INS-1, -2, -4).
struct DiskAppLocator: InstalledAppLocating {
    var searchFolders: [URL]
    var recordedPaths: [String: URL]
    /// Spotlight/LaunchServices lookup, injected for tests.
    var bundleIDLookup: (String) -> [URL]
    var runningBundleIDs: () -> Set<String>

    func installedCopies(of app: RegistryApp) -> [InstalledApp] {
        // Red: not implemented yet.
        []
    }

    func isRunning(_ installed: InstalledApp) -> Bool {
        // Red: not implemented yet.
        false
    }
}

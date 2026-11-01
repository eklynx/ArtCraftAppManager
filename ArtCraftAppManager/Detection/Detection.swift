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
        guard !copies.isEmpty else { return nil }
        let shown = copies.first { $0.url.standardizedFileURL == recordedPath?.standardizedFileURL }
            ?? copies.max { $0.version < $1.version }!
        return ResolvedInstall(shown: shown, others: copies.filter { $0 != shown })
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
        var candidates: [URL] = []
        if let bundleId = app.bundleId { candidates += bundleIDLookup(bundleId) }
        if let recorded = recordedPaths[app.id] { candidates.append(recorded) }
        candidates += searchFolders.map { $0.appendingPathComponent(app.appBundleName) }

        var seen = Set<URL>()
        return candidates.compactMap { url -> InstalledApp? in
            let key = url.standardizedFileURL
            guard seen.insert(key).inserted, let info = Self.readInfo(at: url) else { return nil }
            if let expected = app.bundleId, info.bundleId != expected { return nil }
            return InstalledApp(appId: app.id, bundleId: info.bundleId, url: url, version: info.version)
        }
    }

    func isRunning(_ installed: InstalledApp) -> Bool {
        runningBundleIDs().contains(installed.bundleId)
    }

    static func readInfo(at app: URL) -> (bundleId: String, version: AppVersion)? {
        guard let plist = NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist")),
              let bundleId = plist["CFBundleIdentifier"] as? String,
              let versionString = plist["CFBundleShortVersionString"] as? String,
              let version = AppVersion(versionString) else { return nil }
        return (bundleId, version)
    }
}

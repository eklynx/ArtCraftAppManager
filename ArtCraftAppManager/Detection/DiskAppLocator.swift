import Foundation

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

import CryptoKit
import Foundation

/// Mounts disk images. Production uses `hdiutil`; tests inject a fake.
///
/// **Happy path:** `mount` returns the mount-point folder; `unmount` detaches it.
/// **Errors:** `mount` throws `ManagerError.mountFailed`.
protocol DiskImageMounting {
    func mount(_ dmg: URL, app: String) throws -> URL
    func unmount(_ mountPoint: URL)
}

/// Downloads a file into a folder.
///
/// **Happy path:** returns the downloaded file's URL, reporting progress 0...1.
/// **Errors:** `.offline`, `.diskFull`, `.permissionDenied`; throws `CancellationError` when cancelled
/// (any partial file is removed).
protocol Downloading {
    func download(from url: URL, to folder: URL, app: String, progress: @escaping (Double) -> Void) async throws -> URL
}

/// Moves items to the Trash.
///
/// **Happy path:** the item is moved to the user's Trash.
/// **Errors:** throws if the item can't be moved (permissions, missing item).
protocol Trashing {
    func moveToTrash(_ url: URL) throws
}

/// Launches and reveals Apps (REQ-INS-15).
///
/// **Happy path:** `launch` opens the app; `reveal` shows it in Finder.
/// **Errors:** none thrown; failures are logged.
protocol AppLaunching {
    func launch(_ url: URL)
    func reveal(_ url: URL)
}

/// Installs, updates and uninstalls Apps.
///
/// **Happy path:** `install` places the App in `folder` and returns it; `update` replaces the copy in
/// place (old copy to the Trash only after the new one is verified); `uninstall` moves it to the Trash.
/// **Errors:** `.checksumMismatch`, `.diskFull`, `.permissionDenied`, `.folderMissing`, `.mountFailed`,
/// `.bundleMissing`, `.destinationExists`, `.appRunning`, `.swapFailed`, `.offline`; `CancellationError`.
protocol InstallationManaging {
    func install(_ release: Release, app: RegistryApp, to folder: URL, progress: @escaping (Double) -> Void) async throws -> InstalledApp
    func update(_ installed: InstalledApp, app: RegistryApp, to release: Release, progress: @escaping (Double) -> Void) async throws -> InstalledApp
    func uninstall(_ installed: InstalledApp, app: RegistryApp) async throws
}

enum ChecksumList {
    /// Parses `SHA256SUMS.txt` lines (`<hex>  <name>`) into name → lowercase hex.
    static func parse(_ text: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in text.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count == 2 else { continue }
            let name = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: " *"))
            result[name] = parts[0].lowercased()
        }
        return result
    }

    static func sha256(of url: URL) throws -> String {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

struct DiskInstaller: InstallationManaging {
    var downloader: Downloading
    var mounter: DiskImageMounting
    var trasher: Trashing
    var locator: InstalledAppLocating
    var downloadFolder: URL
    /// Returns checksum list text for a release, if it has one.
    var checksumText: (Release) async throws -> String?

    func install(_ release: Release, app: RegistryApp, to folder: URL, progress: @escaping (Double) -> Void) async throws -> InstalledApp {
        // Red: not implemented yet.
        throw ManagerError.swapFailed(app: app.displayName)
    }

    func update(_ installed: InstalledApp, app: RegistryApp, to release: Release, progress: @escaping (Double) -> Void) async throws -> InstalledApp {
        // Red: not implemented yet.
        throw ManagerError.swapFailed(app: app.displayName)
    }

    func uninstall(_ installed: InstalledApp, app: RegistryApp) async throws {
        // Red: not implemented yet.
        throw ManagerError.swapFailed(app: app.displayName)
    }
}

/// `hdiutil`-backed mounter (REQ-TST-5 integration).
struct HdiutilMounter: DiskImageMounting {
    func mount(_ dmg: URL, app: String) throws -> URL {
        // Red: not implemented yet.
        throw ManagerError.mountFailed(app: app)
    }
    func unmount(_ mountPoint: URL) {}
}

/// Serialises work per App and caps concurrent downloads (REQ-INS-16).
actor OperationScheduler {
    static let maxConcurrentDownloads = 2

    func run<T>(appId: String, isDownload: Bool, work: @escaping () async throws -> T) async throws -> T {
        // Red: not implemented yet (runs immediately, no serialisation).
        try await work()
    }
}

/// Run / Open Location actions (REQ-INS-15).
struct AppActions {
    var launcher: AppLaunching

    func run(_ installed: InstalledApp) {
        // Red: not implemented yet.
    }

    func openLocation(_ installed: InstalledApp) {
        // Red: not implemented yet.
    }
}

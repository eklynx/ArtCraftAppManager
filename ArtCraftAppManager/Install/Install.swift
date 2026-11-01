// SOURCE OF TRUTH (for humans and AI agents): the `Install` namespace contract.
// Types: InstallationManaging, DiskImageMounting, Downloading, Trashing, AppLaunching, OperationScheduler.
// Read the doc comments on each protocol (happy path + errors) before calling into this namespace,
// and the governing spec: docs/specs/03-install-update.md. Other namespaces MUST go through these protocols.

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
    /// Downloads and verifies the release's disk image into the Download Location without installing (Auto Download).
    func download(_ release: Release, app: RegistryApp, progress: @escaping (Double) -> Void) async throws
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
    /// Called after a successful install or update with the new copy (REQ-WIN-23).
    var onInstalled: ((InstalledApp, Release) -> Void)? = nil

    private var fm: FileManager { .default }

    func install(_ release: Release, app: RegistryApp, to folder: URL, progress: @escaping (Double) -> Void) async throws -> InstalledApp {
        try FolderValidator.validate(folder)
        let target = folder.appendingPathComponent(app.appBundleName)
        guard !fm.fileExists(atPath: target.path) else {
            throw ManagerError.destinationExists(app: app.displayName, folder: folder.path)
        }
        let dmg = try await obtainDMG(release, app: app, progress: progress)
        let mountPoint = try mounter.mount(dmg, app: app.displayName)
        defer { mounter.unmount(mountPoint) }
        let source = mountPoint.appendingPathComponent(app.appBundleName)
        guard fm.fileExists(atPath: source.path) else { throw ManagerError.bundleMissing(app: app.displayName) }
        try copy(source, to: target, app: app, folder: folder)
        try? fm.removeItem(at: dmg)
        progress(1.0)
        let result = try installedApp(at: target, app: app)
        onInstalled?(result, release)
        return result
    }

    func update(_ installed: InstalledApp, app: RegistryApp, to release: Release, progress: @escaping (Double) -> Void) async throws -> InstalledApp {
        if locator.isRunning(installed) { throw ManagerError.appRunning(app: app.displayName, operation: .update) }
        let folder = installed.url.deletingLastPathComponent()
        try FolderValidator.validate(folder)
        let dmg = try await obtainDMG(release, app: app, progress: progress)
        let mountPoint = try mounter.mount(dmg, app: app.displayName)
        defer { mounter.unmount(mountPoint) }
        let source = mountPoint.appendingPathComponent(app.appBundleName)
        guard fm.fileExists(atPath: source.path) else { throw ManagerError.bundleMissing(app: app.displayName) }

        // Copy beside the old copy under a temporary name and verify it before touching the old one (REQ-INS-10).
        let token = UUID().uuidString.prefix(8)
        let staged = folder.appendingPathComponent(".\(app.appBundleName).new-\(token)")
        let backup = folder.appendingPathComponent("\(app.displayName).previous-\(token).app")
        do {
            try copy(source, to: staged, app: app, folder: folder)
            if let expected = app.bundleId, DiskAppLocator.readInfo(at: staged)?.bundleId != expected {
                throw ManagerError.swapFailed(app: app.displayName)
            }
        } catch {
            try? fm.removeItem(at: staged)
            throw error
        }

        do {
            try fm.moveItem(at: installed.url, to: backup)
            do { try fm.moveItem(at: staged, to: installed.url) }
            catch { try? fm.moveItem(at: backup, to: installed.url); throw error }
            do { try trasher.moveToTrash(backup) }
            catch {
                try? fm.removeItem(at: installed.url)
                try fm.moveItem(at: backup, to: installed.url)
                throw error
            }
        } catch {
            try? fm.removeItem(at: staged)
            throw ManagerError.swapFailed(app: app.displayName)
        }
        try? fm.removeItem(at: dmg)
        progress(1.0)
        let result = try installedApp(at: installed.url, app: app)
        onInstalled?(result, release)
        return result
    }

    func uninstall(_ installed: InstalledApp, app: RegistryApp) async throws {
        if locator.isRunning(installed) { throw ManagerError.appRunning(app: app.displayName, operation: .uninstall) }
        do { try trasher.moveToTrash(installed.url) }
        catch { throw ManagerError.permissionDenied(folder: installed.url.deletingLastPathComponent().path) }
    }

    func download(_ release: Release, app: RegistryApp, progress: @escaping (Double) -> Void) async throws {
        _ = try await obtainDMG(release, app: app, progress: progress)
    }

    // MARK: - Helpers

    /// Returns a verified disk image in the Download Location, reusing an existing verified one (REQ-INS-12).
    private func obtainDMG(_ release: Release, app: RegistryApp, progress: @escaping (Double) -> Void) async throws -> URL {
        let expected = try await expectedChecksum(for: release)
        let existing = downloadFolder.appendingPathComponent(release.dmgName)
        if let expected, fm.fileExists(atPath: existing.path), (try? ChecksumList.sha256(of: existing)) == expected {
            return existing
        }
        let file: URL
        do {
            file = try await downloader.download(from: release.dmgURL, to: downloadFolder, app: app.displayName, progress: progress)
        } catch {
            try? fm.removeItem(at: existing)  // never leave a partial download behind
            throw error
        }
        if let expected, (try? ChecksumList.sha256(of: file)) != expected {
            try? fm.removeItem(at: file)
            throw ManagerError.checksumMismatch(app: app.displayName)
        }
        return file
    }

    private func expectedChecksum(for release: Release) async throws -> String? {
        guard let text = try await checksumText(release) else { return nil }
        return ChecksumList.parse(text)[release.dmgName]
    }

    private func copy(_ source: URL, to destination: URL, app: RegistryApp, folder: URL) throws {
        do { try fm.copyItem(at: source, to: destination) }
        catch let error as CocoaError {
            switch error.code {
            case .fileWriteOutOfSpace: throw ManagerError.diskFull(app: app.displayName, folder: folder.path)
            case .fileWriteNoPermission: throw ManagerError.permissionDenied(folder: folder.path)
            case .fileWriteFileExists: throw ManagerError.destinationExists(app: app.displayName, folder: folder.path)
            default: throw ManagerError.swapFailed(app: app.displayName)
            }
        }
    }

    private func installedApp(at url: URL, app: RegistryApp) throws -> InstalledApp {
        guard let info = DiskAppLocator.readInfo(at: url) else { throw ManagerError.bundleMissing(app: app.displayName) }
        return InstalledApp(appId: app.id, bundleId: info.bundleId, url: url, version: info.version)
    }
}

/// `hdiutil`-backed mounter (REQ-TST-5 integration).
struct HdiutilMounter: DiskImageMounting {
    func mount(_ dmg: URL, app: String) throws -> URL {
        let output = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["attach", "-nobrowse", "-readonly", "-noautoopen", "-plist", dmg.path]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { throw ManagerError.mountFailed(app: app) }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let entities = plist["system-entities"] as? [[String: Any]],
              let mountPath = entities.compactMap({ $0["mount-point"] as? String }).first
        else { throw ManagerError.mountFailed(app: app) }
        return URL(fileURLWithPath: mountPath)
    }

    func unmount(_ mountPoint: URL) {
        for arguments in [["detach", "-quiet", mountPoint.path], ["detach", "-quiet", "-force", mountPoint.path]] {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
            process.arguments = arguments
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            if (try? process.run()) != nil { process.waitUntilExit() }
            if process.terminationStatus == 0 { return }
        }
    }
}

/// Serialises work per App and caps concurrent downloads (REQ-INS-16).
actor OperationScheduler {
    static let maxConcurrentDownloads = 2

    private var busyApps: Set<String> = []
    private var appWaiters: [String: [CheckedContinuation<Void, Never>]] = [:]
    private var activeDownloads = 0
    private var downloadWaiters: [CheckedContinuation<Void, Never>] = []

    func run<T>(appId: String, isDownload: Bool, work: @escaping () async throws -> T) async throws -> T {
        await acquireApp(appId)
        if isDownload { await acquireDownloadSlot() }
        defer {
            if isDownload { releaseDownloadSlot() }
            releaseApp(appId)
        }
        return try await work()
    }

    private func acquireApp(_ id: String) async {
        if busyApps.contains(id) {
            await withCheckedContinuation { appWaiters[id, default: []].append($0) }
        } else {
            busyApps.insert(id)
        }
    }

    private func releaseApp(_ id: String) {
        if var waiters = appWaiters[id], !waiters.isEmpty {
            let next = waiters.removeFirst()
            appWaiters[id] = waiters
            next.resume()  // ownership passes to the next waiter
        } else {
            busyApps.remove(id)
        }
    }

    private func acquireDownloadSlot() async {
        if activeDownloads < Self.maxConcurrentDownloads {
            activeDownloads += 1
        } else {
            await withCheckedContinuation { downloadWaiters.append($0) }
        }
    }

    private func releaseDownloadSlot() {
        if !downloadWaiters.isEmpty {
            downloadWaiters.removeFirst().resume()  // slot passes to the next waiter
        } else {
            activeDownloads -= 1
        }
    }
}

/// Run / Open Location actions (REQ-INS-15).
struct AppActions {
    var launcher: AppLaunching

    func run(_ installed: InstalledApp) { launcher.launch(installed.url) }
    func openLocation(_ installed: InstalledApp) { launcher.reveal(installed.url) }
}

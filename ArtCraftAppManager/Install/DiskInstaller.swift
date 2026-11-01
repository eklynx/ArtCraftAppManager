import CryptoKit
import Foundation

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

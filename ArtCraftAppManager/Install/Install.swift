// SOURCE OF TRUTH (for humans and AI agents): the `Install` namespace contract.
// Types: InstallationManaging, DiskImageMounting, Downloading, Trashing, AppLaunching.
// Implementations: DiskInstaller.swift, HdiutilMounter.swift, OperationScheduler.swift, AppActions.swift, ChecksumList.swift, URLSessionDownloader.swift, FileManagerTrasher.swift, WorkspaceLauncher.swift, SystemAppLookup.swift.
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

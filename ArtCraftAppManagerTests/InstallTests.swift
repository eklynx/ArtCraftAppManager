import Foundation
import Testing
@testable import ArtCraftAppManager

// docs/specs/03-install-update.md

/// Wires a DiskInstaller over temp folders with fakes.
final class InstallRig {
    let app = makeApp()
    let release = makeRelease("0.15.0")
    let installFolder: URL
    let downloadFolder: URL
    let mountPoint: URL
    let downloader = FakeDownloader()
    let mounter: FakeMounter
    let trasher = FakeTrasher()
    let locator = FakeLocator()
    var checksum: String?

    init(newAppVersion: String? = "0.15.0") throws {
        installFolder = try makeTempDir("install")
        downloadFolder = try makeTempDir("dl")
        mountPoint = try makeTempDir("mnt")
        mounter = FakeMounter(mountPoint: mountPoint)
        if let newAppVersion { try makeStubApp(in: mountPoint, version: newAppVersion) }
    }

    var installer: DiskInstaller {
        DiskInstaller(downloader: downloader, mounter: mounter, trasher: trasher, locator: locator,
                      downloadFolder: downloadFolder, checksumText: { [checksum] _ in checksum })
    }

    var target: URL { installFolder.appendingPathComponent("GridCraft.app") }
    func dmgs() -> [String] { ((try? FileManager.default.contentsOfDirectory(atPath: downloadFolder.path)) ?? []).filter { $0.hasSuffix(".dmg") } }
}

struct InstallTests {
    @Test("REQ-INS-5 / REQ-OVR-1 installs into the chosen folder, records the app, removes the dmg, unmounts")
    func happyInstall() async throws {
        let rig = try InstallRig()
        let installed = try await rig.installer.install(rig.release, app: rig.app, to: rig.installFolder) { _ in }
        #expect(installed.url == rig.target)
        #expect(installedVersion(at: rig.target) == "0.15.0")
        #expect(rig.mounter.unmounted == [rig.mountPoint])
        #expect(rig.dmgs().isEmpty)  // REQ-INS-12
    }

    @Test("REQ-INS-5 fails with destinationExists if the target app already exists")
    func destinationExists() async throws {
        let rig = try InstallRig()
        try makeStubApp(in: rig.installFolder, version: "0.1.0")
        await #expect(throws: ManagerError.destinationExists(app: "GridCraft", folder: rig.installFolder.path)) {
            try await rig.installer.install(rig.release, app: rig.app, to: rig.installFolder) { _ in }
        }
    }

    @Test("REQ-INS-6 checksum mismatch deletes the dmg and installs nothing")
    func checksumMismatch() async throws {
        var rig = try InstallRig()
        rig.checksum = String(repeating: "0", count: 64) + "  \(rig.release.dmgName)\n"
        await #expect(throws: ManagerError.checksumMismatch(app: "GridCraft")) {
            try await rig.installer.install(rig.release, app: rig.app, to: rig.installFolder) { _ in }
        }
        #expect(rig.dmgs().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: rig.target.path))
    }

    @Test("REQ-INS-6 a matching checksum passes; no checksum asset skips verification")
    func checksumOK() async throws {
        let rig = try InstallRig()
        rig.downloader.contents = Data("payload".utf8)
        let tmp = try makeTempDir("sum").appendingPathComponent("x.dmg")
        try rig.downloader.contents.write(to: tmp)
        rig.checksum = "\(try ChecksumList.sha256(of: tmp))  \(rig.release.dmgName)\n"
        _ = try await rig.installer.install(rig.release, app: rig.app, to: rig.installFolder) { _ in }
        #expect(FileManager.default.fileExists(atPath: rig.target.path))

        let noSum = try InstallRig()
        _ = try await noSum.installer.install(noSum.release, app: noSum.app, to: noSum.installFolder) { _ in }
        #expect(FileManager.default.fileExists(atPath: noSum.target.path))
    }

    @Test("REQ-INS-7 the image is unmounted even when the app is missing from it")
    func unmountsOnFailure() async throws {
        let rig = try InstallRig(newAppVersion: nil)
        await #expect(throws: ManagerError.bundleMissing(app: "GridCraft")) {
            try await rig.installer.install(rig.release, app: rig.app, to: rig.installFolder) { _ in }
        }
        #expect(rig.mounter.unmounted == [rig.mountPoint])
    }

    @Test("REQ-INS-7 a mount failure is reported as mountFailed")
    func mountFailure() async throws {
        let rig = try InstallRig()
        rig.mounter.failure = .mountFailed(app: "GridCraft")
        await #expect(throws: ManagerError.mountFailed(app: "GridCraft")) {
            try await rig.installer.install(rig.release, app: rig.app, to: rig.installFolder) { _ in }
        }
    }

    @Test("REQ-INS-8 quarantine on the downloaded app is not stripped")
    func keepsQuarantine() async throws {
        let rig = try InstallRig()
        let staged = rig.mountPoint.appendingPathComponent("GridCraft.app")
        let value = "0083;00000000;Safari;"
        #expect(setxattr(staged.path, "com.apple.quarantine", value, value.utf8.count, 0, 0) == 0)
        _ = try await rig.installer.install(rig.release, app: rig.app, to: rig.installFolder) { _ in }
        #expect(getxattr(rig.target.path, "com.apple.quarantine", nil, 0, 0, 0) > 0)
    }

    @Test("REQ-INS-13 an unwritable folder fails with permissionDenied")
    func permissionDenied() async throws {
        let rig = try InstallRig()
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: rig.installFolder.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: rig.installFolder.path) }
        await #expect(throws: ManagerError.permissionDenied(folder: rig.installFolder.path)) {
            try await rig.installer.install(rig.release, app: rig.app, to: rig.installFolder) { _ in }
        }
    }

    @Test("REQ-INS-17 / REQ-ARC-6 progress is reported and cancelling removes the partial download")
    func progressAndCancel() async throws {
        let rig = try InstallRig()
        let seen = Box<[Double]>([])
        _ = try await rig.installer.install(rig.release, app: rig.app, to: rig.installFolder) { p in seen.value.append(p) }
        #expect(seen.value.contains(0.5) && seen.value.last == 1.0)

        let slow = try InstallRig()
        slow.downloader.suspendUntilCancelled = true
        let task = Task { try await slow.installer.install(slow.release, app: slow.app, to: slow.installFolder) { _ in } }
        try await Task.sleep(nanoseconds: 100_000_000)
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(slow.dmgs().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: slow.target.path))
    }
}

final class Box<T> { var value: T; init(_ v: T) { value = v } }

struct UpdateTests {
    @Test("REQ-INS-9 / REQ-OVR-3 updates in place at the existing location, not the default")
    func updatesInPlace() async throws {
        let rig = try InstallRig()
        let oldFolder = try makeTempDir("external")
        let old = try makeStubApp(in: oldFolder, version: "0.14.0")
        let installed = makeInstalled(rig.app, url: old, version: "0.14.0")
        let result = try await rig.installer.update(installed, app: rig.app, to: rig.release) { _ in }
        #expect(result.url == old)
        #expect(installedVersion(at: old) == "0.15.0")
        #expect(rig.trasher.trashed.count == 1)  // old copy trashed after swap
        #expect(!FileManager.default.fileExists(atPath: rig.target.path))
    }

    @Test("REQ-INS-10 a failure before the swap leaves the old app untouched")
    func failureBeforeSwap() async throws {
        let rig = try InstallRig(newAppVersion: nil)  // dmg has no app
        let old = try makeStubApp(in: rig.installFolder, version: "0.14.0")
        let installed = makeInstalled(rig.app, url: old, version: "0.14.0")
        await #expect(throws: ManagerError.bundleMissing(app: "GridCraft")) {
            try await rig.installer.update(installed, app: rig.app, to: rig.release) { _ in }
        }
        #expect(installedVersion(at: old) == "0.14.0")
        #expect(rig.trasher.trashed.isEmpty)
    }

    @Test("REQ-INS-10 a failed swap restores the previous version and leaves no temp copy")
    func failedSwapRestores() async throws {
        let rig = try InstallRig()
        rig.trasher.shouldFail = true
        let old = try makeStubApp(in: rig.installFolder, version: "0.14.0")
        let installed = makeInstalled(rig.app, url: old, version: "0.14.0")
        await #expect(throws: ManagerError.swapFailed(app: "GridCraft")) {
            try await rig.installer.update(installed, app: rig.app, to: rig.release) { _ in }
        }
        #expect(installedVersion(at: old) == "0.14.0")
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: rig.installFolder.path)
        #expect(leftovers == ["GridCraft.app"])
    }

    @Test("REQ-INS-11 updating or uninstalling a running app is blocked and never quits it")
    func runningBlocked() async throws {
        let rig = try InstallRig()
        rig.locator.running = true
        let old = try makeStubApp(in: rig.installFolder, version: "0.14.0")
        let installed = makeInstalled(rig.app, url: old, version: "0.14.0")
        await #expect(throws: ManagerError.appRunning(app: "GridCraft", operation: .update)) {
            try await rig.installer.update(installed, app: rig.app, to: rig.release) { _ in }
        }
        await #expect(throws: ManagerError.appRunning(app: "GridCraft", operation: .uninstall)) {
            try await rig.installer.uninstall(installed, app: rig.app)
        }
        #expect(ManagerError.appRunning(app: "GridCraft", operation: .update).statusText == "Quit GridCraft to update.")
        #expect(installedVersion(at: old) == "0.14.0")
    }

    @Test("REQ-INS-12 a verified, already-downloaded dmg is reused instead of downloading again")
    func reusesDownloadedDmg() async throws {
        let rig = try InstallRig()
        let dmg = rig.downloadFolder.appendingPathComponent(rig.release.dmgName)
        try Data("dmg".utf8).write(to: dmg)
        rig.checksum = "\(try ChecksumList.sha256(of: dmg))  \(rig.release.dmgName)\n"
        let old = try makeStubApp(in: rig.installFolder, version: "0.14.0")
        _ = try await rig.installer.update(makeInstalled(rig.app, url: old, version: "0.14.0"), app: rig.app, to: rig.release) { _ in }
        #expect(rig.downloader.calls == 0)
    }

    @Test("REQ-INS-13 an update into an unwritable location fails with permissionDenied")
    func updatePermission() async throws {
        let rig = try InstallRig()
        let old = try makeStubApp(in: rig.installFolder, version: "0.14.0")
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: rig.installFolder.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: rig.installFolder.path) }
        await #expect(throws: ManagerError.permissionDenied(folder: rig.installFolder.path)) {
            try await rig.installer.update(makeInstalled(rig.app, url: old, version: "0.14.0"), app: rig.app, to: rig.release) { _ in }
        }
    }
}

struct UninstallAndActionsTests {
    @Test("REQ-INS-14 uninstall moves the app to the Trash and keeps user data")
    func uninstall() async throws {
        let rig = try InstallRig()
        let old = try makeStubApp(in: rig.installFolder, version: "0.14.0")
        let prefs = rig.installFolder.appendingPathComponent("prefs.plist")  // stands in for user data
        try Data("x".utf8).write(to: prefs)
        try await rig.installer.uninstall(makeInstalled(rig.app, url: old, version: "0.14.0"), app: rig.app)
        #expect(rig.trasher.trashed == [old])
        #expect(FileManager.default.fileExists(atPath: prefs.path))
    }

    @Test("REQ-INS-15 Run launches and Open Location reveals the shown copy")
    func runAndReveal() {
        let launcher = FakeLauncher()
        let installed = makeInstalled(url: URL(fileURLWithPath: "/Volumes/X/GridCraft.app"), version: "1.0.0")
        let actions = AppActions(launcher: launcher)
        actions.run(installed)
        actions.openLocation(installed)
        #expect(launcher.launched == [installed.url])
        #expect(launcher.revealed == [installed.url])
    }
}

struct SchedulingTests {
    @Test("REQ-INS-16 operations on the same app run one at a time")
    func serialPerApp() async throws {
        let scheduler = OperationScheduler()
        let active = Box(0), maxActive = Box(0)
        func work() async throws {
            active.value += 1; maxActive.value = max(maxActive.value, active.value)
            try await Task.sleep(nanoseconds: 50_000_000)
            active.value -= 1
        }
        async let a: Void = scheduler.run(appId: "gridcraft", isDownload: false, work: work)
        async let b: Void = scheduler.run(appId: "gridcraft", isDownload: false, work: work)
        _ = try await (a, b)
        #expect(maxActive.value == 1)
    }

    @Test("REQ-INS-16 at most two downloads run at once across apps")
    func twoDownloads() async throws {
        let scheduler = OperationScheduler()
        let active = Box(0), maxActive = Box(0)
        func work() async throws {
            active.value += 1; maxActive.value = max(maxActive.value, active.value)
            try await Task.sleep(nanoseconds: 80_000_000)
            active.value -= 1
        }
        try await withThrowingTaskGroup(of: Void.self) { group in
            for id in ["a", "b", "c", "d"] { group.addTask { try await scheduler.run(appId: id, isDownload: true, work: work) } }
            try await group.waitForAll()
        }
        #expect(maxActive.value <= OperationScheduler.maxConcurrentDownloads)
        #expect(maxActive.value == 2)
    }
}

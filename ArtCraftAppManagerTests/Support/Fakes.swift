import Foundation
@testable import ArtCraftAppManager

final class FakeHTTPTransport: HTTPTransport {
    var responder: (URLRequest) throws -> (Data, Int, [String: String])
    private(set) var requests: [URLRequest] = []
    init(_ responder: @escaping (URLRequest) throws -> (Data, Int, [String: String])) { self.responder = responder }
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let (data, status, headers) = try responder(request)
        return (data, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!)
    }
}

struct FakeTokenProvider: TokenProviding {
    var value: String?
    func token() -> String? { value }
}

final class FakeDownloader: Downloading {
    var contents = Data("dmg".utf8)
    var suspendUntilCancelled = false
    var failure: ManagerError?
    private(set) var calls = 0
    func download(from url: URL, to folder: URL, app: String, progress: @escaping (Double) -> Void) async throws -> URL {
        calls += 1
        if let failure { throw failure }
        let file = folder.appendingPathComponent(url.lastPathComponent)
        try contents.write(to: file)
        progress(0.5)
        if suspendUntilCancelled {
            while true { try await Task.sleep(nanoseconds: 10_000_000) }
        }
        progress(1.0)
        return file
    }
}

final class FakeMounter: DiskImageMounting {
    let mountPoint: URL
    var failure: ManagerError?
    private(set) var unmounted: [URL] = []
    init(mountPoint: URL) { self.mountPoint = mountPoint }
    func mount(_ dmg: URL, app: String) throws -> URL {
        if let failure { throw failure }
        return mountPoint
    }
    func unmount(_ mountPoint: URL) { unmounted.append(mountPoint) }
}

final class FakeTrasher: Trashing {
    var shouldFail = false
    private(set) var trashed: [URL] = []
    func moveToTrash(_ url: URL) throws {
        if shouldFail { throw CocoaError(.fileWriteNoPermission) }
        trashed.append(url)
        try FileManager.default.removeItem(at: url)
    }
}

final class FakeLauncher: AppLaunching {
    private(set) var launched: [URL] = []
    private(set) var revealed: [URL] = []
    func launch(_ url: URL) { launched.append(url) }
    func reveal(_ url: URL) { revealed.append(url) }
}

final class FakeLocator: InstalledAppLocating {
    var copies: [InstalledApp] = []
    var running = false
    func installedCopies(of app: RegistryApp) -> [InstalledApp] { copies }
    func isRunning(_ installed: InstalledApp) -> Bool { running }
}

final class FakeNotifier: UpdateNotifying {
    var allowed = true
    private(set) var posted: [(NotificationKind, String, String)] = []
    func requestAuthorization() async -> Bool { allowed }
    func post(kind: NotificationKind, appId: String, appName: String, version: String) async {
        posted.append((kind, appId, version))
    }
}

final class FakeRunningAppsObserver: RunningAppsObserving {
    private var continuation: AsyncStream<Void>.Continuation?
    private(set) var isObserving = false
    func changes() -> AsyncStream<Void> { isObserving = true; return AsyncStream { continuation = $0 } }
    func emit() { continuation?.yield() }
    func finish() { continuation?.finish() }
}

final class FakeQuitObserver: QuitObserving {
    var quit = false
    func waitForQuit(of installed: InstalledApp) async {}
}

final class FakeReporter: StatusReporting {
    private(set) var errors: [ManagerError] = []
    private(set) var badge = false
    func show(_ error: ManagerError) { errors.append(error) }
    func setAttentionBadge(_ on: Bool) { badge = on }
}

final class FakeLoginItem: LoginItemControlling {
    var failure: Error?
    private(set) var enabled = false
    func setEnabled(_ enabled: Bool) throws {
        if let failure { throw failure }
        self.enabled = enabled
    }
}

final class FakeInstaller: InstallationManaging {
    private(set) var installs = 0, updates = 0, downloads = 0
    var failure: ManagerError?
    var result: InstalledApp
    init(result: InstalledApp) { self.result = result }
    func install(_ release: Release, app: RegistryApp, to folder: URL, progress: @escaping (Double) -> Void) async throws -> InstalledApp {
        installs += 1
        if let failure { throw failure }
        return result
    }
    func update(_ installed: InstalledApp, app: RegistryApp, to release: Release, progress: @escaping (Double) -> Void) async throws -> InstalledApp {
        updates += 1
        if let failure { throw failure }
        return result
    }
    func uninstall(_ installed: InstalledApp, app: RegistryApp) async throws {}
    func download(_ release: Release, app: RegistryApp, progress: @escaping (Double) -> Void) async throws {
        downloads += 1
        if let failure { throw failure }
    }
}

final class InMemoryStateStore: ManagerStateStoring {
    var state = ManagerState()
    func load() -> ManagerState { state }
    func save(_ state: ManagerState) throws { self.state = state }
}

struct FakeFetcher: ReleaseFetching {
    var delayNanos: UInt64 = 0
    func latestRelease(for app: RegistryApp, etag: String?) async throws -> ReleaseResult {
        try await Task.sleep(nanoseconds: delayNanos)
        return .notModified
    }
}

final class FakeRegistryProvider: AppRegistryProviding {
    var registry: AppRegistry
    private(set) var refreshes = 0
    init(registry: AppRegistry) { self.registry = registry }
    func current() async -> AppRegistry { registry }
    func refresh() async { refreshes += 1 }
}

final class InMemorySettings: SettingsStoring {
    var defaultInstallLocation = URL(fileURLWithPath: "/Applications")
    var downloadLocation = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
    var enabledAppIds: Set<String>?
    var autoDownload = false
    var autoInstall = false
    var launchAtLogin = false
    var appOrder: [String]?
    var managerAutoCheck = true
    var managerUpdateChannel: ManagerUpdateChannel = .release
}

/// In-memory icon source: returns canned data per App id (REQ-ARC-3, REQ-WIN-25).
final class FakeIconProvider: AppIconProviding {
    var icons: [String: Data] = [:]
    private(set) var requested: [String] = []
    func icon(for app: RegistryApp) async -> Data? {
        requested.append(app.id)
        return icons[app.id]
    }
}

@MainActor
final class FakeManagerUpdater: ManagerUpdating {
    var canCheckForUpdates = true
    var automaticallyChecks = true
    var channel: ManagerUpdateChannel = .release
    private(set) var checks = 0
    func checkForUpdates() { checks += 1 }
}


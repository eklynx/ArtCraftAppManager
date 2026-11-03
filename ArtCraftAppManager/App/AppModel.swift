import AppKit
import Foundation
import Observation

/// Composition root and observable app state. Wires the concrete adapters behind the module protocols
/// (REQ-ARC-1); the SwiftUI layer only talks to this type.
@MainActor @Observable
final class AppModel {
    struct Row: Identifiable {
        var id: String
        var name: String
        var app: RegistryApp?
        var installed: InstalledApp?
        var available: Release?
        var isRunning = false
        var inRegistry = true
        var installedByManagerAt: Date?
        var releasedAt: Date?
        var fileDate: Date?
    }

    // MARK: Observable state
    private(set) var registry: AppRegistry
    private(set) var rows: [Row] = []
    /// Downloaded icons for Apps that are not installed (REQ-WIN-25).
    private(set) var cachedIcons: [String: NSImage] = [:]
    private(set) var progress: [String: Double] = [:]
    private(set) var status = StatusLine()
    private(set) var isChecking = false
    var scrollTarget: String?
    let startedByLoginItem: Bool

    // MARK: Settings (mirrored so SwiftUI observes them)
    var defaultInstallLocation: URL { didSet { store.defaultInstallLocation = defaultInstallLocation } }
    var downloadLocation: URL { didSet { store.downloadLocation = downloadLocation } }
    private(set) var enabledIds: Set<String>
    private(set) var policy: UpdatePolicy
    private(set) var launchAtLogin: Bool
    private(set) var appOrder: [String]?
    private(set) var managerAutoCheck: Bool
    private(set) var managerChannel: ManagerUpdateChannel
    /// Updates the Manager itself (REQ-UPD-1); disabled in Debug builds and test runs (REQ-UPD-6).
    let managerUpdater: ManagerUpdating
    private let tokenStore = KeychainTokenProvider()
    /// Optional GitHub token, kept in the Keychain (REQ-SET-9).
    var githubToken: String { didSet { tokenStore.save(githubToken) } }

    // MARK: Collaborators
    private let store: SettingsStoring
    private let state: ManagerStateStoring
    private let transport: HTTPTransport
    private let registryProvider: AppRegistryProviding
    private let fetcher: ReleaseFetching
    private let scheduler = OperationScheduler()
    private let notifier: UserNotificationNotifier
    private let notifications: UpdateNotificationService
    private let loginItem: SettingsController
    private let actions = AppActions(launcher: WorkspaceLauncher())
    private var autoUpdate: AutoUpdateController!
    private var latest: [String: Release] = [:]
    private var tasks: [String: Task<Void, Never>] = [:]
    private var timer: Task<Void, Never>?
    private var runningWatcher: Task<Void, Never>?
    private var started = false
    /// UI tests: pretend GitHub is unreachable without touching the network.
    private var forcedOffline = false
    /// Test launches never touch the network.
    private let networkDisabled: Bool
    private let iconProvider: AppIconProviding

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        // UI-test launches use an isolated defaults suite and state folder so they never touch real data.
        let isUITest = arguments.contains { $0.hasPrefix("-uitest") }
        let isTestHost = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        networkDisabled = isUITest || isTestHost
        let defaults: UserDefaults
        let supportDir: URL
        if isUITest || isTestHost {
            defaults = UserDefaults(suiteName: "com.eklynx.ArtCraftAppManager.uitest")!
            defaults.removePersistentDomain(forName: "com.eklynx.ArtCraftAppManager.uitest")
            supportDir = FileManager.default.temporaryDirectory.appendingPathComponent("acam-uitest-state")
            try? FileManager.default.removeItem(at: supportDir)
        } else {
            defaults = .standard
            supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("ArtCraftAppManager")
        }
        let settings = UserDefaultsSettingsStore(defaults: defaults)
        store = settings
        state = JSONStateStore(url: supportDir.appendingPathComponent("state.json"))
        transport = URLSessionTransport()
        let cacheRoot = isUITest || isTestHost
            ? FileManager.default.temporaryDirectory.appendingPathComponent("acam-uitest-cache")
            : FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("ArtCraftAppManager")
        iconProvider = GitHubIconProvider(transport: transport, cacheFolder: cacheRoot.appendingPathComponent("icons"))
        let bundled = (try? BundledRemoteRegistryProvider.loadBundled())
            ?? AppRegistry(schemaVersion: AppRegistry.supportedSchemaVersion, updated: "", owner: "", apps: [])
        registry = bundled
        registryProvider = BundledRemoteRegistryProvider(bundled: bundled, transport: transport, state: state, tokens: KeychainTokenProvider())
        fetcher = GitHubReleaseFetcher(transport: transport, tokens: KeychainTokenProvider())
        notifier = UserNotificationNotifier()
        notifications = UpdateNotificationService(notifier: notifier, state: state)
        loginItem = SettingsController(store: settings, loginItem: SMAppServiceLoginItem())

        defaultInstallLocation = settings.defaultInstallLocation
        downloadLocation = settings.downloadLocation
        enabledIds = arguments.contains("-uitest-no-enabled-apps") ? [] : settings.enabledIds(in: bundled)
        var initialPolicy = UpdatePolicy()
        initialPolicy.setAutoInstall(settings.autoInstall)
        if !settings.autoInstall { initialPolicy.setAutoDownload(settings.autoDownload) }
        policy = initialPolicy
        appOrder = settings.appOrder
        managerAutoCheck = settings.managerAutoCheck
        managerChannel = settings.managerUpdateChannel
        #if DEBUG
        managerUpdater = DisabledManagerUpdater(automaticallyChecks: settings.managerAutoCheck, channel: settings.managerUpdateChannel)
        #else
        managerUpdater = isUITest || isTestHost
            ? DisabledManagerUpdater(automaticallyChecks: settings.managerAutoCheck, channel: settings.managerUpdateChannel)
            : SparkleManagerUpdater(automaticallyChecks: settings.managerAutoCheck, channel: settings.managerUpdateChannel)
        #endif
        githubToken = isUITest || isTestHost ? "" : (KeychainTokenProvider().token() ?? "")
        launchAtLogin = settings.launchAtLogin || arguments.contains("-uitest-started-by-login-item")
        startedByLoginItem = arguments.contains("-uitest-started-by-login-item") || Self.launchedAsLoginItem()

        autoUpdate = AutoUpdateController(installer: makeInstaller(), locator: makeLocator(), notifications: notifications,
                                          quitObserver: WorkspaceQuitObserver(), reporter: ModelReporter(self))
        notifier.onClick = { [weak self] id in self?.reveal(id) }
        applyUITestScenario(arguments)
        rebuildRows()
    }

    private static func launchedAsLoginItem() -> Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent else { return false }
        return event.eventID == AEEventID(kAEOpenApplication)
            && event.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue == OSType(keyAELaunchedAsLogInItem)
    }

    // MARK: Lifecycle

    func start() async {
        guard !started else { return }
        started = true
        // Keep the Running label and the disabled Update/Uninstall buttons in step with real launches and quits (REQ-WIN-27).
        runningWatcher = Task { [weak self] in
            await RunningStateRefresher(observer: WorkspaceRunningAppsObserver()).run { self?.rebuildRows() }
        }
        await notifications.start()
        await refresh()
        timer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(UpdateCoordinator.interval))
                await self?.refresh()
            }
        }
    }

    // MARK: Icons (REQ-WIN-25)

    /// Loads (cached or downloaded) icons for every registry App that is not installed. Silent on failure.
    func loadIcons() async {
        if networkDisabled { return }
        let installedIds = Set(rows.filter { $0.installed != nil }.map(\.id))
        for app in registry.apps where !installedIds.contains(app.id) && cachedIcons[app.id] == nil {
            if let data = await iconProvider.icon(for: app), let image = NSImage(data: data) { cachedIcons[app.id] = image }
        }
    }

    /// The icon to show for an App: installed copy's icon, else the cached download, else nil (placeholder).
    func iconImage(forAppId id: String) -> NSImage? {
        let installedURL = rows.first { $0.id == id }?.installed?.url
        switch IconChoice.source(installed: installedURL != nil, cached: cachedIcons[id] != nil) {
        case .installed: return NSWorkspace.shared.icon(forFile: installedURL!.path)
        case .cached: return cachedIcons[id]
        case .placeholder: return nil
        }
    }

    // MARK: Update checks (REQ-REG-12)

    func refresh() async {
        guard !isChecking else { return }
        if forcedOffline { status.show(.offline); return }
        if networkDisabled { return }
        isChecking = true
        defer { isChecking = false }
        await registryProvider.refresh()
        registry = await registryProvider.current()
        var saved = state.load()
        var failure: ManagerError?
        for app in registry.apps where enabledIds.contains(app.id) {
            do {
                let etag = latest[app.id] == nil ? nil : saved.etags[app.id]
                switch try await fetcher.latestRelease(for: app, etag: etag) {
                case .release(let release, let newTag):
                    latest[app.id] = release
                    if let published = release.publishedAt {
                        saved.publishDates[ManagerState.stampKey(appId: app.id, version: release.version.description)] = published
                    }
                    saved.etags[app.id] = newTag
                case .notModified:
                    break
                }
            } catch let error as ManagerError {
                failure = failure ?? error
                if case .rateLimited = error { break }
            } catch {}
        }
        try? state.save(saved)
        rebuildRows()
        if let failure { status.show(failure) } else { status.operationSucceeded(); noteDuplicates() }
        await applyAutoUpdates()
        await loadIcons()
    }

    private func applyAutoUpdates() async {
        for row in rows {
            guard let app = row.app, let installed = row.installed, let release = row.available,
                  release.version > installed.version else { continue }
            await autoUpdate.handleNewRelease(app: app, installed: installed, release: release, policy: policy,
                                              windowVisible: NSApp.windows.contains { $0.isVisible })
        }
        rebuildRows()
    }

    // MARK: Row building

    func rebuildRows() {
        let locator = makeLocator()
        let savedState = state.load()
        let recorded = savedState.recordedPaths
        let window = MainWindowModel()
        window.setRows(registry: registry, enabled: enabledIds, removedFromRegistry: [], order: appOrder)
        var built: [Row] = window.rowIds.compactMap { id in
            guard let app = registry.apps.first(where: { $0.id == id }) else { return nil }
            let resolved = InstallResolver.resolve(copies: locator.installedCopies(of: app),
                                                   recordedPath: recorded[id].map { URL(fileURLWithPath: $0) })
            var row = Row(id: id, name: app.displayName, app: app, installed: resolved?.shown, available: latest[id],
                          isRunning: resolved.map { locator.isRunning($0.shown) } ?? false)
            if let shown = resolved?.shown {
                let key = ManagerState.stampKey(appId: id, version: shown.version.description)
                row.installedByManagerAt = savedState.installDates[key]
                row.releasedAt = savedState.publishDates[key]
                row.fileDate = (try? shown.url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            }
            return row
        }
        // Installed apps that left the registry stay listed (REQ-REG-4).
        for (id, path) in recorded where !registry.apps.contains(where: { $0.id == id }) {
            let url = URL(fileURLWithPath: path)
            guard let info = DiskAppLocator.readInfo(at: url) else { continue }
            let installed = InstalledApp(appId: id, bundleId: info.bundleId, url: url, version: info.version)
            built.append(Row(id: id, name: id, app: nil, installed: installed, isRunning: locator.isRunning(installed), inRegistry: false))
        }
        rows = built
    }

    private func noteDuplicates() {
        let locator = makeLocator()
        let recorded = state.load().recordedPaths
        for app in registry.apps where enabledIds.contains(app.id) {
            if let resolved = InstallResolver.resolve(copies: locator.installedCopies(of: app),
                                                      recordedPath: recorded[app.id].map { URL(fileURLWithPath: $0) }),
               let other = resolved.others.first {
                status.show(.duplicateCopy(app: app.displayName, path: other.url.path))
                return
            }
        }
    }

    func rowModel(for row: Row) -> AppRowModel {
        AppRowModel(name: row.name, installed: row.installed, available: row.available, isRunning: row.isRunning,
                    progress: progress[row.id], inRegistry: row.inRegistry,
                    installedByManagerAt: row.installedByManagerAt, releasedAt: row.releasedAt, fileDate: row.fileDate)
    }

    /// Context-menu actions that need more than the row's own state (REQ-WIN-22).
    func copyInstallPath(_ row: Row) {
        guard let path = row.installed?.url.path else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path, forType: .string)
    }

    func openReleasesPage(_ row: Row) {
        guard let url = (row.app ?? registry.apps.first { $0.id == row.id })?.releasesUrl else { return }
        NSWorkspace.shared.open(url)
    }

    var menuBarModel: MenuBarModel {
        MenuBarModel(entries: rows.compactMap { row in
            guard row.inRegistry, let installed = row.installed, let available = row.available?.version,
                  available > installed.version else { return nil }
            return .init(appId: row.id, name: row.name, installed: installed.version, available: available)
        })
    }

    // MARK: User actions

    func install(_ row: Row, to folder: URL) {
        guard let app = row.app, let release = latest[row.id] else { status.show(.releaseUnusable(app: row.name)); return }
        runOperation(row.id) { [self] in
            let installed = try await makeInstaller().install(release, app: app, to: folder) { [weak self] value in
                Task { @MainActor in self?.progress[row.id] = value }
            }
            record(installed)
        }
    }

    func update(_ row: Row) {
        guard let app = row.app, let installed = row.installed, let release = row.available else { return }
        if row.isRunning { status.show(.appRunning(app: row.name, operation: .update)); return }
        runOperation(row.id) { [self] in
            let updated = try await makeInstaller().update(installed, app: app, to: release) { [weak self] value in
                Task { @MainActor in self?.progress[row.id] = value }
            }
            record(updated)
        }
    }

    func uninstall(_ row: Row) {
        guard let app = row.app ?? registry.apps.first(where: { $0.id == row.id }) ?? stubApp(row), let installed = row.installed else { return }
        if row.isRunning { status.show(.appRunning(app: row.name, operation: .uninstall)); return }
        runOperation(row.id) { [self] in
            try await makeInstaller().uninstall(installed, app: app)
            var saved = state.load()
            saved.recordedPaths[row.id] = nil
            try? state.save(saved)
        }
    }

    func run(_ row: Row) { row.installed.map(actions.run) }
    func openLocation(_ row: Row) { row.installed.map(actions.openLocation) }
    func cancel(_ row: Row) { tasks[row.id]?.cancel() }

    func clearStatus() { status.tapped() }

    func reveal(_ appId: String) {
        scrollTarget = notifications.rowToReveal(forClickedNotificationOf: appId)
    }

    private func runOperation(_ id: String, _ work: @escaping () async throws -> Void) {
        progress[id] = 0
        tasks[id] = Task { [weak self] in
            do {
                try await self?.scheduler.run(appId: id, isDownload: true, work: work)
                self?.status.operationSucceeded()
            } catch let error as ManagerError {
                self?.status.show(error)
            } catch {}
            self?.progress[id] = nil
            self?.tasks[id] = nil
            self?.rebuildRows()
        }
    }

    private func record(_ installed: InstalledApp) {
        var saved = state.load()
        saved.recordedPaths[installed.appId] = installed.url.path
        saved.lastSeenVersions[installed.appId] = installed.version.description
        try? state.save(saved)
    }

    private func stubApp(_ row: Row) -> RegistryApp? { nil }

    // MARK: Settings changes

    func setEnabled(_ id: String, _ on: Bool) {
        if on { enabledIds.insert(id) } else { enabledIds.remove(id) }
        store.enabledAppIds = enabledIds
        rebuildRows()
    }

    /// All registry apps in the App order, for the Settings list (REQ-SET-10).
    var orderedApps: [RegistryApp] { AppOrder.ordered(registry.apps, saved: appOrder) }
    var isDefaultOrder: Bool { orderedApps.map(\.id) == registry.apps.map(\.id) }

    func moveApps(from offsets: IndexSet, to destination: Int) {
        applyOrder(AppOrder.moved(orderedApps.map(\.id), fromOffsets: offsets, toOffset: destination))
    }

    func moveApp(_ id: String, by delta: Int) {
        applyOrder(AppOrder.shifted(orderedApps.map(\.id), id: id, by: delta))
    }

    func resetOrder() { applyOrder(registry.apps.map(\.id)) }

    private func applyOrder(_ ids: [String]) {
        appOrder = AppOrder.storable(ids, registry: registry.apps)
        store.appOrder = appOrder
        rebuildRows()
    }

    func setAutoDownload(_ on: Bool) {
        policy.setAutoDownload(on)
        store.autoDownload = policy.autoDownload
    }

    func setAutoInstall(_ on: Bool) {
        policy.setAutoInstall(on)
        store.autoInstall = policy.autoInstall
        store.autoDownload = policy.autoDownload
    }

    func setManagerAutoCheck(_ on: Bool) {
        managerAutoCheck = on
        managerUpdater.automaticallyChecks = on
        store.managerAutoCheck = on
    }

    func setManagerChannel(_ channel: ManagerUpdateChannel) {
        managerChannel = channel
        managerUpdater.channel = channel
        store.managerUpdateChannel = channel
    }

    func setLaunchAtLogin(_ on: Bool) {
        if let error = loginItem.setLaunchAtLogin(on) { status.show(error) }
        launchAtLogin = store.launchAtLogin
    }

    /// Validates and applies a folder picked in Settings (REQ-SET-2).
    func chooseFolder(_ folder: URL, forInstall: Bool) {
        do {
            try FolderValidator.validate(folder)
            if forInstall { defaultInstallLocation = folder } else { downloadLocation = folder }
        } catch let error as ManagerError {
            status.show(error)
        } catch {}
    }

    // MARK: Factories

    private func makeLocator() -> DiskAppLocator {
        DiskAppLocator(searchFolders: [defaultInstallLocation, URL(fileURLWithPath: "/Applications")],
                       recordedPaths: state.load().recordedPaths.mapValues { URL(fileURLWithPath: $0) },
                       bundleIDLookup: SystemAppLookup.urls(forBundleID:),
                       runningBundleIDs: SystemAppLookup.runningBundleIDs)
    }

    private func makeInstaller() -> DiskInstaller {
        let transport = self.transport
        let state = self.state
        return DiskInstaller(downloader: URLSessionDownloader(), mounter: HdiutilMounter(), trasher: FileManagerTrasher(),
                             locator: makeLocator(), downloadFolder: downloadLocation,
                             checksumText: { release in
                                 guard let url = release.checksumURL else { return nil }
                                 guard let (data, response) = try? await transport.send(URLRequest(url: url)) else { throw ManagerError.offline }
                                 return response.statusCode == 200 ? String(decoding: data, as: UTF8.self) : nil
                             },
                             onInstalled: { installed, release in
                                 var saved = state.load()
                                 let key = ManagerState.stampKey(appId: installed.appId, version: installed.version.description)
                                 saved.installDates[key] = Date()
                                 if let published = release.publishedAt { saved.publishDates[key] = published }
                                 try? state.save(saved)
                             })
    }

    fileprivate func report(_ error: ManagerError) { status.show(error) }
    fileprivate var hasAttentionBadge = false
    fileprivate func setBadge(_ on: Bool) { hasAttentionBadge = on }

    // MARK: UI-test scenarios (launch arguments)

    private func applyUITestScenario(_ arguments: [String]) {
        if arguments.contains("-uitest-offline") { forcedOffline = true; status.show(.offline) }
        let prefix = "-uitest-installed-"
        if let flag = arguments.first(where: { $0.hasPrefix(prefix) }),
           let app = registry.apps.first(where: { $0.id == String(flag.dropFirst(prefix.count)) }) {
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("acam-uitest")
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let bundle = folder.appendingPathComponent(app.appBundleName)
            let contents = bundle.appendingPathComponent("Contents")
            try? FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
            let plist: NSDictionary = ["CFBundleIdentifier": app.bundleId ?? "x", "CFBundleShortVersionString": "0.1.0"]
            plist.write(to: contents.appendingPathComponent("Info.plist"), atomically: true)
            var saved = state.load()
            saved.recordedPaths[app.id] = bundle.path
            try? state.save(saved)
            enabledIds.insert(app.id)
        }
    }
}

/// Bridges the nonisolated `StatusReporting` protocol to the main-actor model.
private final class ModelReporter: StatusReporting, @unchecked Sendable {
    private weak var model: AppModel?
    init(_ model: AppModel) { self.model = model }
    func show(_ error: ManagerError) { Task { @MainActor in model?.report(error) } }
    func setAttentionBadge(_ on: Bool) { Task { @MainActor in model?.setBadge(on) } }
}

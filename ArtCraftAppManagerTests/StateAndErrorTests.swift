import Foundation
import Testing
@testable import ArtCraftAppManager

// docs/specs/07-errors-and-status.md and 08-architecture.md (state file)

struct ErrorTests {
    private let all: [ManagerError] = [
        .offline, .rateLimited(resetAt: Date(timeIntervalSince1970: 0)), .releaseUnusable(app: "A"), .checksumMismatch(app: "A"),
        .diskFull(app: "A", folder: "/f"), .permissionDenied(folder: "/f"), .folderMissing(folder: "/f"), .mountFailed(app: "A"),
        .bundleMissing(app: "A"), .destinationExists(app: "A", folder: "/f"), .appRunning(app: "A", operation: .update),
        .swapFailed(app: "A"), .loginItemFailed, .registryInvalid, .duplicateCopy(app: "A", path: "/p"),
    ]

    @Test("REQ-ERR-1 every error has a unique code; only registryInvalid is silent")
    func codesAndTexts() {
        #expect(Set(all.map(\.code)).count == all.count)
        for error in all where error != .registryInvalid { #expect(error.statusText?.isEmpty == false, "\(error.code)") }
        #expect(ManagerError.registryInvalid.statusText == nil)
    }

    @Test("REQ-ERR-1 status text matches the catalogue")
    func texts() {
        #expect(ManagerError.offline.statusText == "Can't reach GitHub. Showing last known versions.")
        #expect(ManagerError.permissionDenied(folder: "/Volumes/X").statusText == "Can't write to /Volumes/X.")
        #expect(ManagerError.destinationExists(app: "GridCraft", folder: "/A").statusText == "/A/GridCraft.app already exists.")
    }

    @Test("REQ-ERR-2 the status line shows only the latest message")
    func latestOnly() {
        var line = StatusLine()
        line.show(.offline)
        line.show(.permissionDenied(folder: "/x"))
        #expect(line.text == "Can't write to /x.")
    }

    @Test("REQ-ERR-3 one app's failure does not block the others")
    func perAppIsolation() async {
        let installed = makeInstalled(url: URL(fileURLWithPath: "/x/A.app"), version: "1.0.0")
        let installer = FakeInstaller(result: installed)
        installer.failure = .swapFailed(app: "A")
        let reporter = FakeReporter()
        let notifier = FakeNotifier()
        let controller = AutoUpdateController(installer: installer, locator: FakeLocator(),
                                              notifications: UpdateNotificationService(notifier: notifier, state: InMemoryStateStore()),
                                              quitObserver: FakeQuitObserver(), reporter: reporter)
        var policy = UpdatePolicy(); policy.setAutoInstall(true)
        await controller.handleNewRelease(app: makeApp("a", name: "A"), installed: installed, release: makeRelease("2.0.0"), policy: policy, windowVisible: true)
        installer.failure = nil
        await controller.handleNewRelease(app: makeApp("b", name: "B"), installed: installed, release: makeRelease("2.0.0"), policy: policy, windowVisible: true)
        #expect(installer.updates == 2)
        #expect(notifier.posted.contains { $0.0 == .updateInstalled })
    }
}

struct StateStoreTests {
    @Test("REQ-ARC-4 state round-trips through the JSON file")
    func roundTrip() throws {
        let url = try makeTempDir("state").appendingPathComponent("state.json")
        let store = JSONStateStore(url: url)
        var state = ManagerState()
        state.recordedPaths["gridcraft"] = "/Volumes/X/GridCraft.app"
        state.notified.insert("updateReady|gridcraft|0.15.0")
        try store.save(state)
        #expect(JSONStateStore(url: url).load() == state)
    }

    @Test("REQ-ARC-4 / REQ-INS-4 a corrupt or missing state file loads as empty state without throwing")
    func corruptIsEmpty() throws {
        let dir = try makeTempDir("corrupt")
        let url = dir.appendingPathComponent("state.json")
        try Data("{not json".utf8).write(to: url)
        #expect(JSONStateStore(url: url).load() == ManagerState())
        #expect(JSONStateStore(url: dir.appendingPathComponent("absent.json")).load() == ManagerState())
    }

    @Test("REQ-ARC-4 deleting the state file never touches user settings")
    func settingsSeparate() throws {
        let suite = "acam-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let settings = UserDefaultsSettingsStore(defaults: defaults)
        settings.autoInstall = true
        let url = try makeTempDir("sep").appendingPathComponent("state.json")
        try JSONStateStore(url: url).save(ManagerState())
        try FileManager.default.removeItem(at: url)
        #expect(settings.autoInstall)
    }
}

import Foundation
import Testing
@testable import ArtCraftAppManager

// docs/specs/05-settings.md

struct SettingsTests {
    private func freshStore() -> UserDefaultsSettingsStore {
        let suite = "acam-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return UserDefaultsSettingsStore(defaults: defaults)
    }

    @Test("REQ-SET-7 / REQ-SET-8 defaults match the spec and changes persist immediately")
    func defaultsAndPersistence() {
        let store = freshStore()
        #expect(store.defaultInstallLocation.path == "/Applications")
        #expect(store.downloadLocation.path.hasSuffix("/Downloads"))
        #expect(store.enabledAppIds == nil)
        #expect(!store.autoDownload && !store.autoInstall && !store.launchAtLogin)
        store.autoDownload = true
        store.defaultInstallLocation = URL(fileURLWithPath: "/Volumes/Second/Apps")
        #expect(store.autoDownload)
        #expect(store.defaultInstallLocation.path == "/Volumes/Second/Apps")
    }

    @Test("REQ-SET-3 enabled apps default to the registry's enabledByDefault and new apps follow it")
    func enabledApps() throws {
        let store = freshStore()
        var registry = try loadRegistryFile()
        registry.apps[1].enabledByDefault = false
        #expect(store.enabledIds(in: registry) == Set(registry.apps.filter(\.enabledByDefault).map(\.id)))
        store.enabledAppIds = ["gridcraft"]
        #expect(store.enabledIds(in: registry) == ["gridcraft"])
    }

    @Test("REQ-SET-1 the pickers' state: a chosen folder is accepted when it exists and is writable")
    func acceptsGoodFolder() throws {
        let folder = try makeTempDir("good")
        #expect(throws: Never.self) { try FolderValidator.validate(folder) }
    }

    @Test("REQ-SET-2 a missing folder is rejected as folderMissing")
    func rejectsMissing() {
        let missing = URL(fileURLWithPath: "/Volumes/DoesNotExist-\(UUID().uuidString)")
        #expect(throws: ManagerError.folderMissing(folder: missing.path)) { try FolderValidator.validate(missing) }
    }

    @Test("REQ-SET-2 a read-only folder is rejected as permissionDenied")
    func rejectsReadOnly() throws {
        let folder = try makeTempDir("ro")
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: folder.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder.path) }
        #expect(throws: ManagerError.permissionDenied(folder: folder.path)) { try FolderValidator.validate(folder) }
    }

    @Test("REQ-SET-4 / REQ-SET-5 Auto Install forces and locks Auto Download; turning it off unlocks and keeps the value")
    func autoToggleCoupling() {
        var policy = UpdatePolicy()
        policy.setAutoInstall(true)
        #expect(policy.autoInstall && policy.autoDownload && policy.isAutoDownloadLocked)
        policy.setAutoDownload(false)  // locked: ignored
        #expect(policy.autoDownload)
        policy.setAutoInstall(false)
        #expect(!policy.isAutoDownloadLocked && policy.autoDownload)
        policy.setAutoDownload(false)
        #expect(!policy.autoDownload)
    }

    @Test("REQ-SET-6 Launch at login registers with the login item service")
    func loginItemOn() {
        let store = freshStore(), item = FakeLoginItem()
        let error = SettingsController(store: store, loginItem: item).setLaunchAtLogin(true)
        #expect(error == nil && item.enabled && store.launchAtLogin)
    }

    @Test("REQ-SET-6 a registration failure reverts the toggle and reports loginItemFailed")
    func loginItemFails() {
        let store = freshStore(), item = FakeLoginItem()
        item.failure = CocoaError(.fileWriteNoPermission)
        let error = SettingsController(store: store, loginItem: item).setLaunchAtLogin(true)
        #expect(error == .loginItemFailed)
        #expect(!store.launchAtLogin)
    }
}

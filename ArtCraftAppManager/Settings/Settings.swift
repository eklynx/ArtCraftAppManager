// SOURCE OF TRUTH (for humans and AI agents): the `Settings` namespace contract.
// Types: SettingsStoring, LoginItemControlling, UpdatePolicy, FolderValidator.
// Read the doc comments on each protocol (happy path + errors) before calling into this namespace,
// and the governing spec: docs/specs/05-settings.md. Other namespaces MUST go through these protocols.

import Foundation

/// Persists user settings (REQ-SET-8).
///
/// **Happy path:** reads return the stored value or the spec default; writes persist immediately.
/// **Errors:** none thrown; validation is `FolderValidator`'s job.
protocol SettingsStoring: AnyObject {
    var defaultInstallLocation: URL { get set }
    var downloadLocation: URL { get set }
    /// nil means "never customised": use each registry app's `enabledByDefault`.
    var enabledAppIds: Set<String>? { get set }
    var autoDownload: Bool { get set }
    var autoInstall: Bool { get set }
    var launchAtLogin: Bool { get set }
    /// nil means "never reordered": use the registry order (REQ-SET-10).
    var appOrder: [String]? { get set }
}

extension SettingsStoring {
    func enabledIds(in registry: AppRegistry) -> Set<String> {
        enabledAppIds ?? Set(registry.apps.filter(\.enabledByDefault).map(\.id))
    }
}

final class UserDefaultsSettingsStore: SettingsStoring {
    private let defaults: UserDefaults
    init(defaults: UserDefaults) { self.defaults = defaults }

    var defaultInstallLocation: URL {
        get { defaults.string(forKey: "defaultInstallLocation").map { URL(fileURLWithPath: $0) } ?? URL(fileURLWithPath: "/Applications") }
        set { defaults.set(newValue.path, forKey: "defaultInstallLocation") }
    }
    var downloadLocation: URL {
        get { defaults.string(forKey: "downloadLocation").map { URL(fileURLWithPath: $0) } ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads") }
        set { defaults.set(newValue.path, forKey: "downloadLocation") }
    }
    var enabledAppIds: Set<String>? {
        get { (defaults.array(forKey: "enabledAppIds") as? [String]).map(Set.init) }
        set { defaults.set(newValue.map { Array($0).sorted() }, forKey: "enabledAppIds") }
    }
    var autoDownload: Bool {
        get { defaults.bool(forKey: "autoDownload") }
        set { defaults.set(newValue, forKey: "autoDownload") }
    }
    var autoInstall: Bool {
        get { defaults.bool(forKey: "autoInstall") }
        set { defaults.set(newValue, forKey: "autoInstall") }
    }
    var launchAtLogin: Bool {
        get { defaults.bool(forKey: "launchAtLogin") }
        set { defaults.set(newValue, forKey: "launchAtLogin") }
    }
    var appOrder: [String]? {
        get { defaults.array(forKey: "appOrder") as? [String] }
        set { defaults.set(newValue, forKey: "appOrder") }
    }
}

/// The user's App order (REQ-SET-10).
enum AppOrder {
    /// Apps in the saved order; unknown ids are ignored and missing apps are appended in registry order.
    static func ordered(_ apps: [RegistryApp], saved: [String]?) -> [RegistryApp] {
        guard let saved, !saved.isEmpty else { return apps }
        let byId = Dictionary(apps.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var seen = Set<String>()
        var result = saved.compactMap { id -> RegistryApp? in
            guard let app = byId[id], seen.insert(id).inserted else { return nil }
            return app
        }
        result += apps.filter { !seen.contains($0.id) }
        return result
    }

    /// Moves the items at `offsets` so they land before the element currently at `destination` (SwiftUI `onMove` semantics).
    static func moved(_ ids: [String], fromOffsets offsets: IndexSet, toOffset destination: Int) -> [String] {
        let moving = offsets.sorted().map { ids[$0] }
        var rest = ids
        for index in offsets.sorted().reversed() { rest.remove(at: index) }
        let insertAt = destination - offsets.filter { $0 < destination }.count
        rest.insert(contentsOf: moving, at: max(0, min(insertAt, rest.count)))
        return rest
    }

    /// Moves one id up (-1) or down (+1); returns the input unchanged at the ends.
    static func shifted(_ ids: [String], id: String, by delta: Int) -> [String] {
        guard let index = ids.firstIndex(of: id), ids.indices.contains(index + delta) else { return ids }
        var result = ids
        result.swapAt(index, index + delta)
        return result
    }

    /// The value to store: nil when the order equals the registry order.
    static func storable(_ ids: [String], registry: [RegistryApp]) -> [String]? {
        ids == registry.map(\.id) ? nil : ids
    }
}

/// Coupling between the two auto toggles (REQ-SET-4).
struct UpdatePolicy: Equatable {
    var autoDownload = false
    var autoInstall = false
    /// True while Auto Install forces Auto Download on.
    var isAutoDownloadLocked: Bool { autoInstall }

    mutating func setAutoInstall(_ on: Bool) {
        autoInstall = on
        if on { autoDownload = true }
    }

    mutating func setAutoDownload(_ on: Bool) {
        guard !isAutoDownloadLocked else { return }
        autoDownload = on
    }
}

enum FolderValidator {
    /// - Throws: `.folderMissing` if the folder does not exist, `.permissionDenied` if it is not writable (REQ-SET-2).
    static func validate(_ folder: URL) throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw ManagerError.folderMissing(folder: folder.path)
        }
        guard FileManager.default.isWritableFile(atPath: folder.path) else {
            throw ManagerError.permissionDenied(folder: folder.path)
        }
    }
}

/// Registers the Manager as a login item (`SMAppService.mainApp` in production).
///
/// **Happy path:** `setEnabled` registers or unregisters the login item.
/// **Errors:** throws if registration fails or needs approval in System Settings.
protocol LoginItemControlling {
    /// - Throws: any error if registration fails or needs approval.
    func setEnabled(_ enabled: Bool) throws
}

final class SettingsController {
    let store: SettingsStoring
    let loginItem: LoginItemControlling

    init(store: SettingsStoring, loginItem: LoginItemControlling) {
        self.store = store
        self.loginItem = loginItem
    }

    /// Sets Launch at login; on failure the stored value reverts and `.loginItemFailed` is returned (REQ-SET-6).
    @discardableResult
    func setLaunchAtLogin(_ on: Bool) -> ManagerError? {
        let previous = store.launchAtLogin
        do {
            try loginItem.setEnabled(on)
            store.launchAtLogin = on
            return nil
        } catch {
            store.launchAtLogin = previous
            return .loginItemFailed
        }
    }
}

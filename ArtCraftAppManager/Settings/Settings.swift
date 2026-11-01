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
}

/// Coupling between the two auto toggles (REQ-SET-4).
struct UpdatePolicy: Equatable {
    var autoDownload = false
    var autoInstall = false
    /// True while Auto Install forces Auto Download on.
    var isAutoDownloadLocked: Bool { false /* Red: not implemented yet. */ }

    mutating func setAutoInstall(_ on: Bool) {
        // Red: not implemented yet.
        autoInstall = on
    }

    mutating func setAutoDownload(_ on: Bool) {
        // Red: not implemented yet.
        autoDownload = on
    }
}

enum FolderValidator {
    /// - Throws: `.folderMissing` if the folder does not exist, `.permissionDenied` if it is not writable (REQ-SET-2).
    static func validate(_ folder: URL) throws {
        // Red: not implemented yet.
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
        // Red: not implemented yet.
        nil
    }
}

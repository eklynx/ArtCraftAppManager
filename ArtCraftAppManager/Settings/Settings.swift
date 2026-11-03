// SOURCE OF TRUTH (for humans and AI agents): the `Settings` namespace contract.
// Types: SettingsStoring, LoginItemControlling.
// Implementations: UserDefaultsSettingsStore.swift, SettingsController.swift, AppOrder.swift, UpdatePolicy.swift, FolderValidator.swift, SMAppServiceLoginItem.swift.
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
    /// Check for Manager updates automatically; default on (REQ-UPD-4).
    var managerAutoCheck: Bool { get set }
    /// Which Manager builds to be offered; default `.release` (REQ-UPD-2).
    var managerUpdateChannel: ManagerUpdateChannel { get set }
}

extension SettingsStoring {
    func enabledIds(in registry: AppRegistry) -> Set<String> {
        enabledAppIds ?? Set(registry.apps.filter(\.enabledByDefault).map(\.id))
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

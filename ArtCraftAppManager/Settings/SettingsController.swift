import Foundation

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

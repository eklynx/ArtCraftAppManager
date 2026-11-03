import Foundation

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
    var managerAutoCheck: Bool {
        get { defaults.object(forKey: "managerAutoCheck") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "managerAutoCheck") }
    }
    var managerUpdateChannel: ManagerUpdateChannel {
        get { defaults.string(forKey: "managerUpdateChannel").flatMap(ManagerUpdateChannel.init(rawValue:)) ?? .release }
        set { defaults.set(newValue.rawValue, forKey: "managerUpdateChannel") }
    }
}

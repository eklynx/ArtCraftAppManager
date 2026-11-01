import Foundation

/// One App entry of docs/registry/apps.json (docs/specs/02-app-registry.md).
struct RegistryApp: Codable, Equatable, Identifiable {
    var id: String
    var displayName: String
    var repo: String
    var releasesUrl: URL
    var apiLatestUrl: URL
    var tagPattern: String
    var assetPattern: String
    var checksumAsset: String?
    var bundleId: String?
    var appBundleName: String
    var iconUrl: URL?
    var enabledByDefault: Bool
}

struct AppRegistry: Codable, Equatable {
    static let supportedSchemaVersion = 1

    var schemaVersion: Int
    var updated: String
    var owner: String
    var apps: [RegistryApp]
}

enum RegistryLocations {
    /// REQ-REG-2
    static let remoteURL = URL(string: "https://raw.githubusercontent.com/eklynx/ArtCraftAppManager/main/docs/registry/apps.json")!
}

/// Supplies the active registry.
///
/// **Happy path:** `current()` returns the best available registry — fresh remote, else cached, else bundled.
/// **Errors:** never throws; an invalid or unreachable remote falls back silently (logged as `registryInvalid`).
protocol AppRegistryProviding {
    /// The registry currently in effect. Always succeeds (the bundled copy is the floor).
    func current() async -> AppRegistry
    /// Fetches the remote copy and caches it if valid (REQ-REG-2/3). Failures are swallowed.
    func refresh() async
}

enum RegistryValidator {
    /// Decodes and validates registry JSON.
    /// - Throws: `ManagerError.registryInvalid` for malformed JSON, schema violations,
    ///   an unsupported `schemaVersion`, or duplicate app ids (REQ-REG-3, REQ-REG-5).
    static func validate(_ data: Data) throws -> AppRegistry {
        guard let registry = try? JSONDecoder().decode(AppRegistry.self, from: data),
              registry.schemaVersion == AppRegistry.supportedSchemaVersion,
              !registry.apps.isEmpty,
              Set(registry.apps.map(\.id)).count == registry.apps.count,
              registry.apps.allSatisfy(isValid)
        else { throw ManagerError.registryInvalid }
        return registry
    }

    private static func isValid(_ app: RegistryApp) -> Bool {
        !app.id.isEmpty && !app.displayName.isEmpty && app.repo.split(separator: "/").count == 2
            && app.appBundleName.hasSuffix(".app")
            && [app.tagPattern, app.assetPattern].allSatisfy { $0.contains("(?<version>") && (try? NSRegularExpression(pattern: $0)) != nil }
    }

    /// Picks the registry in effect: valid remote, else valid cached, else bundled (REQ-REG-3).
    static func select(remote: Data?, cached: Data?, bundled: AppRegistry) -> AppRegistry {
        for candidate in [remote, cached] {
            if let candidate, let registry = try? validate(candidate) { return registry }
        }
        return bundled
    }
}

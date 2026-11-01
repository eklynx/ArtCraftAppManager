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
        // Red: not implemented yet.
        throw ManagerError.registryInvalid
    }

    /// Picks the registry in effect: valid remote, else valid cached, else bundled (REQ-REG-3).
    static func select(remote: Data?, cached: Data?, bundled: AppRegistry) -> AppRegistry {
        // Red: not implemented yet.
        bundled
    }
}

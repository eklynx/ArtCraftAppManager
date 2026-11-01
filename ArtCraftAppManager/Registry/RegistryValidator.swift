import Foundation

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

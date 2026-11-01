import Foundation

/// Bundled registry with a validated, cached remote refresh (ADR 0002, REQ-REG-1..3).
final class BundledRemoteRegistryProvider: AppRegistryProviding {
    private let bundled: AppRegistry
    private let transport: HTTPTransport
    private let state: ManagerStateStoring
    private let remoteURL: URL
    private let tokens: TokenProviding?

    init(bundled: AppRegistry, transport: HTTPTransport, state: ManagerStateStoring,
         remoteURL: URL = RegistryLocations.remoteURL, tokens: TokenProviding? = nil) {
        self.tokens = tokens
        self.bundled = bundled
        self.transport = transport
        self.state = state
        self.remoteURL = remoteURL
    }

    /// Loads the `apps.json` shipped in the app bundle (REQ-REG-1).
    static func loadBundled(from bundle: Bundle = .main) throws -> AppRegistry {
        guard let url = bundle.url(forResource: "apps", withExtension: "json") else { throw ManagerError.registryInvalid }
        return try RegistryValidator.validate(Data(contentsOf: url))
    }

    func current() async -> AppRegistry {
        RegistryValidator.select(remote: nil, cached: state.load().cachedRegistry, bundled: bundled)
    }

    func refresh() async {
        var request = URLRequest(url: remoteURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        // A GitHub token lets the refresh read a private repository (REQ-REG-11).
        if let token = tokens?.token() { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        guard let (data, response) = try? await transport.send(request), response.statusCode == 200,
              (try? RegistryValidator.validate(data)) != nil else { return }
        var saved = state.load()
        saved.cachedRegistry = data
        try? state.save(saved)
    }
}

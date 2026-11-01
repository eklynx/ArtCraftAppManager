import Foundation

/// Dotted numeric version, compared per component (REQ-REG-8).
struct AppVersion: Comparable, Equatable, CustomStringConvertible {
    let components: [Int]
    var description: String { components.map(String.init).joined(separator: ".") }

    init?(_ string: String) {
        // Red: not implemented yet (returns an empty version so callers don't crash).
        components = []
    }

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        // Red: not implemented yet.
        false
    }
}

struct Release: Equatable {
    var version: AppVersion
    var tag: String
    var dmgURL: URL
    var dmgName: String
    var checksumURL: URL?
}

enum ReleaseResult: Equatable {
    case release(Release, etag: String?)
    case notModified
}

/// Looks up the latest usable Release of an App on GitHub.
///
/// **Happy path:** returns `.release` for the newest non-draft, non-prerelease release whose tag and
/// asset match the App's patterns, or `.notModified` when the supplied ETag is still current (HTTP 304).
/// **Errors:** `.offline`, `.rateLimited(resetAt:)`, `.releaseUnusable(app:)`.
protocol ReleaseFetching {
    func latestRelease(for app: RegistryApp, etag: String?) async throws -> ReleaseResult
}

/// Network seam so tests never touch the network (REQ-TST-3).
///
/// **Happy path:** returns the response body and HTTP response for the request.
/// **Errors:** connectivity failures surface as `URLError`.
protocol HTTPTransport {
    /// - Throws: any `URLError` for connectivity failures.
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

/// Optional GitHub token source (Keychain-backed in production, REQ-REG-11).
///
/// **Happy path:** returns a token to raise the rate limit.
/// **Errors:** none thrown; nil means "no token" and requests go unauthenticated.
protocol TokenProviding {
    func token() -> String?
}

enum ReleaseResolver {
    /// Turns a GitHub `releases/latest` JSON body into a usable Release (REQ-REG-6, REQ-REG-7).
    /// - Throws: `ManagerError.releaseUnusable` for draft/prerelease, tag mismatch, or zero/multiple matching assets.
    static func resolve(app: RegistryApp, json: Data) throws -> Release {
        // Red: not implemented yet.
        throw ManagerError.releaseUnusable(app: app.displayName)
    }
}

struct GitHubReleaseFetcher: ReleaseFetching {
    var transport: HTTPTransport
    var tokens: TokenProviding?

    func latestRelease(for app: RegistryApp, etag: String?) async throws -> ReleaseResult {
        // Red: not implemented yet.
        throw ManagerError.offline
    }
}

/// Runs update checks (REQ-REG-12).
actor UpdateCoordinator {
    static let interval: TimeInterval = 6 * 60 * 60

    private let fetcher: ReleaseFetching
    init(fetcher: ReleaseFetching) { self.fetcher = fetcher }

    /// Checks all given apps. Returns false (and does nothing) if a check is already in flight.
    func checkNow(apps: [RegistryApp]) async -> Bool {
        // Red: not implemented yet.
        false
    }
}

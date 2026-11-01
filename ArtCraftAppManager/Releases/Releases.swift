// SOURCE OF TRUTH (for humans and AI agents): the `Releases` namespace contract.
// Types: ReleaseFetching, HTTPTransport, TokenProviding, AppVersion, Release, ReleaseResult.
// Implementations: ReleaseResolver.swift, GitHubReleaseFetcher.swift, UpdateCoordinator.swift, URLSessionTransport.swift, KeychainTokenProvider.swift.
// Read the doc comments on each protocol (happy path + errors) before calling into this namespace,
// and the governing spec: docs/specs/02-app-registry.md. Other namespaces MUST go through these protocols.

import Foundation

/// Dotted numeric version, compared per component (REQ-REG-8).
struct AppVersion: Comparable, Equatable, CustomStringConvertible {
    let components: [Int]
    var description: String { components.map(String.init).joined(separator: ".") }

    /// Parses `major.minor.patch` (any number of numeric components). Returns nil for anything else.
    init?(_ string: String) {
        let parts = string.split(separator: ".", omittingEmptySubsequences: false)
        let numbers = parts.compactMap { Int($0) }
        guard !parts.isEmpty, numbers.count == parts.count, numbers.allSatisfy({ $0 >= 0 }) else { return nil }
        components = numbers
    }

    private func padded(to count: Int) -> [Int] { components + Array(repeating: 0, count: max(0, count - components.count)) }

    static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let n = max(lhs.components.count, rhs.components.count)
        return lhs.padded(to: n) == rhs.padded(to: n)
    }

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let n = max(lhs.components.count, rhs.components.count)
        return lhs.padded(to: n).lexicographicallyPrecedes(rhs.padded(to: n))
    }
}

struct Release: Equatable {
    var version: AppVersion
    var tag: String
    var dmgURL: URL
    var dmgName: String
    var checksumURL: URL?
    /// GitHub `published_at`, when present (REQ-WIN-23).
    var publishedAt: Date? = nil
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

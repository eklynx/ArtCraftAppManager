// SOURCE OF TRUTH (for humans and AI agents): the `Releases` namespace contract.
// Types: ReleaseFetching, HTTPTransport, TokenProviding, AppVersion, ReleaseResolver, UpdateCoordinator.
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
        let unusable = ManagerError.releaseUnusable(app: app.displayName)
        guard let object = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
              let tag = object["tag_name"] as? String,
              (object["draft"] as? Bool) != true, (object["prerelease"] as? Bool) != true,
              let tagVersion = version(in: tag, pattern: app.tagPattern),
              let rawAssets = object["assets"] as? [[String: Any]],
              let assetRegex = try? NSRegularExpression(pattern: app.assetPattern)
        else { throw unusable }

        let assets = rawAssets.compactMap { dict -> (name: String, url: URL)? in
            guard let name = dict["name"] as? String, let urlString = dict["browser_download_url"] as? String,
                  let url = URL(string: urlString) else { return nil }
            return (name, url)
        }
        let dmgs = assets.filter { assetRegex.firstMatch(in: $0.name, range: NSRange($0.name.startIndex..., in: $0.name)) != nil }
        guard dmgs.count == 1 else { throw unusable }
        let checksum = app.checksumAsset.flatMap { wanted in assets.first { $0.name == wanted }?.url }
        return Release(version: tagVersion, tag: tag, dmgURL: dmgs[0].url, dmgName: dmgs[0].name, checksumURL: checksum)
    }

    private static func version(in text: String, pattern: String) -> AppVersion? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(withName: "version"), in: text) else { return nil }
        return AppVersion(String(text[range]))
    }
}

struct GitHubReleaseFetcher: ReleaseFetching {
    var transport: HTTPTransport
    var tokens: TokenProviding?

    func latestRelease(for app: RegistryApp, etag: String?) async throws -> ReleaseResult {
        var request = URLRequest(url: app.apiLatestUrl)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        if let etag { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        if let token = tokens?.token() { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }

        let data: Data, response: HTTPURLResponse
        do { (data, response) = try await transport.send(request) }
        catch is CancellationError { throw CancellationError() }
        catch { throw ManagerError.offline }

        switch response.statusCode {
        case 304:
            return .notModified
        case 200:
            let release = try ReleaseResolver.resolve(app: app, json: data)
            return .release(release, etag: response.value(forHTTPHeaderField: "ETag"))
        case 403, 429:
            let exhausted = response.value(forHTTPHeaderField: "X-RateLimit-Remaining") == "0" || response.statusCode == 429
            guard exhausted else { throw ManagerError.releaseUnusable(app: app.displayName) }
            let reset = response.value(forHTTPHeaderField: "X-RateLimit-Reset").flatMap(TimeInterval.init)
            throw ManagerError.rateLimited(resetAt: reset.map { Date(timeIntervalSince1970: $0) } ?? Date().addingTimeInterval(60))
        case 404:
            throw ManagerError.releaseUnusable(app: app.displayName)
        default:
            throw ManagerError.offline
        }
    }
}

/// Runs update checks (REQ-REG-12).
actor UpdateCoordinator {
    static let interval: TimeInterval = 6 * 60 * 60

    private let fetcher: ReleaseFetching
    private var isChecking = false
    init(fetcher: ReleaseFetching) { self.fetcher = fetcher }

    /// Checks all given apps. Returns false (and does nothing) if a check is already in flight.
    func checkNow(apps: [RegistryApp]) async -> Bool {
        guard !isChecking else { return false }
        isChecking = true
        defer { isChecking = false }
        for app in apps {
            if Task.isCancelled { break }
            _ = try? await fetcher.latestRelease(for: app, etag: nil)
        }
        return true
    }
}

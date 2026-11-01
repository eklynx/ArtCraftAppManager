import Foundation

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

import AppKit
import Foundation

/// Downloads icons from `raw.githubusercontent.com` into a disposable cache folder. Public repos only, so no token is sent.
struct GitHubIconProvider: AppIconProviding {
    var transport: HTTPTransport
    var cacheFolder: URL
    var now: () -> Date = { Date() }
    static let maxBytes = 2_000_000
    static let recheckInterval: TimeInterval = 24 * 3600

    private struct Meta: Codable { var etag: String?; var checkedAt: Date }

    func icon(for app: RegistryApp) async -> Data? {
        guard let url = app.iconUrl else { return nil }
        let file = cacheFolder.appendingPathComponent("\(app.id).png")
        let metaFile = cacheFolder.appendingPathComponent("\(app.id).json")
        let cached = try? Data(contentsOf: file)
        let meta = (try? Data(contentsOf: metaFile)).flatMap { try? JSONDecoder().decode(Meta.self, from: $0) }

        if let cached, let meta, now().timeIntervalSince(meta.checkedAt) < Self.recheckInterval { return cached }

        var request = URLRequest(url: url)
        if cached != nil, let etag = meta?.etag { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        guard let (data, response) = try? await transport.send(request) else { return cached }

        func remember(_ etag: String?) {
            try? FileManager.default.createDirectory(at: cacheFolder, withIntermediateDirectories: true)
            if let encoded = try? JSONEncoder().encode(Meta(etag: etag, checkedAt: now())) { try? encoded.write(to: metaFile, options: .atomic) }
        }
        switch response.statusCode {
        case 304 where cached != nil:
            remember(meta?.etag)
            return cached
        case 200 where data.count <= Self.maxBytes && NSImage(data: data) != nil:
            try? FileManager.default.createDirectory(at: cacheFolder, withIntermediateDirectories: true)
            try? data.write(to: file, options: .atomic)
            remember(response.value(forHTTPHeaderField: "ETag"))
            return data
        default:
            return cached
        }
    }
}

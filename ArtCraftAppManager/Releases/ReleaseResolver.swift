import Foundation

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
        return Release(version: tagVersion, tag: tag, dmgURL: dmgs[0].url, dmgName: dmgs[0].name, checksumURL: checksum,
                       publishedAt: (object["published_at"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) })
    }

    private static func version(in text: String, pattern: String) -> AppVersion? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(withName: "version"), in: text) else { return nil }
        return AppVersion(String(text[range]))
    }
}

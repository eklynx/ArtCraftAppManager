import Foundation
@testable import ArtCraftAppManager

/// Locates the repo and fixtures from this file's path (tests run unsandboxed, ADR 0001).
enum Repo {
    static let root: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    static let specs = root.appendingPathComponent("docs/specs")
    static let registryFile = root.appendingPathComponent("docs/registry/apps.json")
    static let schemaFile = root.appendingPathComponent("docs/registry/apps.schema.json")
    static let appSources = root.appendingPathComponent("ArtCraftAppManager")
    static let unitTests = root.appendingPathComponent("ArtCraftAppManagerTests")
    static let uiTests = root.appendingPathComponent("ArtCraftAppManagerUITests")
    static let pbxproj = root.appendingPathComponent("ArtCraftAppManager.xcodeproj/project.pbxproj")
    static func fixture(_ name: String) -> URL { unitTests.appendingPathComponent("Fixtures/\(name)") }

    static func swiftFiles(in dir: URL) -> [URL] {
        guard let e = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil) else { return [] }
        return e.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }
}

func loadRegistryFile() throws -> AppRegistry {
    try JSONDecoder().decode(AppRegistry.self, from: Data(contentsOf: Repo.registryFile))
}

func makeApp(_ id: String = "gridcraft", name: String = "GridCraft", bundleId: String? = "ai.storyteller.gridcraft",
             checksum: String? = "SHA256SUMS.txt") -> RegistryApp {
    RegistryApp(id: id, displayName: name, repo: "storytold/\(id)",
                releasesUrl: URL(string: "https://github.com/storytold/\(id)/releases")!,
                apiLatestUrl: URL(string: "https://api.github.com/repos/storytold/\(id)/releases/latest")!,
                tagPattern: #"^v(?<version>\d+\.\d+\.\d+)$"#,
                assetPattern: "^\(id)-(?<version>\\d+\\.\\d+\\.\\d+)-macos-universal\\.dmg$",
                checksumAsset: checksum, bundleId: bundleId, appBundleName: "\(name).app", iconUrl: nil, enabledByDefault: true)
}

func makeTempDir(_ label: String = "t") throws -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("acam-\(label)-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

/// Creates a stub `.app` bundle with an Info.plist.
@discardableResult
func makeStubApp(in folder: URL, name: String = "GridCraft", bundleId: String = "ai.storyteller.gridcraft", version: String) throws -> URL {
    let app = folder.appendingPathComponent("\(name).app")
    let contents = app.appendingPathComponent("Contents")
    try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
    let plist: [String: Any] = ["CFBundleIdentifier": bundleId, "CFBundleShortVersionString": version, "CFBundleName": name]
    try (plist as NSDictionary).write(to: contents.appendingPathComponent("Info.plist"))
    return app
}

func installedVersion(at app: URL) -> String? {
    NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist"))?["CFBundleShortVersionString"] as? String
}

func makeInstalled(_ app: RegistryApp = makeApp(), url: URL, version: String) -> InstalledApp {
    InstalledApp(appId: app.id, bundleId: app.bundleId ?? "x", url: url, version: AppVersion(version)!)
}

func makeRelease(_ version: String, app: RegistryApp = makeApp()) -> Release {
    let name = "\(app.id)-\(version)-macos-universal.dmg"
    return Release(version: AppVersion(version)!, tag: "v\(version)",
                   dmgURL: URL(string: "https://example.invalid/\(name)")!, dmgName: name,
                   checksumURL: app.checksumAsset.map { _ in URL(string: "https://example.invalid/SHA256SUMS.txt")! })
}

func releaseJSON(tag: String, assets: [String], draft: Bool = false, prerelease: Bool = false) -> Data {
    let obj: [String: Any] = [
        "tag_name": tag, "draft": draft, "prerelease": prerelease,
        "assets": assets.map { ["name": $0, "browser_download_url": "https://example.invalid/\($0)"] },
    ]
    return try! JSONSerialization.data(withJSONObject: obj)
}

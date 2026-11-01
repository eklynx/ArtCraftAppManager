import Foundation
import Testing
@testable import ArtCraftAppManager

// docs/specs/02-app-registry.md

struct RegistryFileTests {
    @Test("REQ-TST-4 apps.json has the schema's required shape")
    func registryShape() throws {
        let schema = try JSONSerialization.jsonObject(with: Data(contentsOf: Repo.schemaFile)) as! [String: Any]
        let appDef = ((schema["$defs"] as! [String: Any])["app"]) as! [String: Any]
        let required = Set(appDef["required"] as! [String])
        let root = try JSONSerialization.jsonObject(with: Data(contentsOf: Repo.registryFile)) as! [String: Any]
        let apps = root["apps"] as! [[String: Any]]
        #expect(root["schemaVersion"] as? Int == AppRegistry.supportedSchemaVersion)
        #expect(apps.count == 14)
        for app in apps {
            #expect(Set(app.keys) == required, "keys differ for \(app["id"] ?? "?")")
        }
    }

    @Test("REQ-TST-4 ids unique, patterns compile and have a version group")
    func patternsCompile() throws {
        let registry = try loadRegistryFile()
        #expect(Set(registry.apps.map(\.id)).count == registry.apps.count)
        for app in registry.apps {
            for pattern in [app.tagPattern, app.assetPattern] {
                let regex = try NSRegularExpression(pattern: pattern)
                #expect(pattern.contains("(?<version>"), "\(app.id) pattern lacks version group")
                _ = regex
            }
        }
    }

    @Test("REQ-TST-4 every app's patterns match its captured latest-release fixture")
    func patternsMatchFixtures() throws {
        for app in try loadRegistryFile().apps {
            let json = try JSONSerialization.jsonObject(with: Data(contentsOf: Repo.fixture("releases/\(app.id).json"))) as! [String: Any]
            let tag = json["tag_name"] as! String
            let assets = (json["assets"] as! [[String: Any]]).map { $0["name"] as! String }
            let tagRegex = try NSRegularExpression(pattern: app.tagPattern)
            let assetRegex = try NSRegularExpression(pattern: app.assetPattern)
            func matches(_ r: NSRegularExpression, _ s: String) -> Bool {
                r.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil
            }
            #expect(matches(tagRegex, tag), "\(app.id) tag \(tag)")
            #expect(assets.filter { matches(assetRegex, $0) }.count == 1, "\(app.id) dmg asset")
            if let checksum = app.checksumAsset { #expect(assets.contains(checksum), "\(app.id) checksum asset") }
        }
    }

    @Test("REQ-REG-1 / REQ-ARC-7 a copy of apps.json ships in the app bundle")
    func bundledCopy() throws {
        #expect(Bundle.main.url(forResource: "apps", withExtension: "json") != nil)
    }

    @Test("REQ-REG-2 remote registry URL points at this repo's main branch")
    func remoteURL() {
        #expect(RegistryLocations.remoteURL.absoluteString ==
                "https://raw.githubusercontent.com/eklynx/ArtCraftAppManager/main/docs/registry/apps.json")
    }
}

struct RegistrySelectionTests {
    let bundled = try! loadRegistryFile()

    private func data(_ mutate: (inout AppRegistry) -> Void) -> Data {
        var r = bundled; mutate(&r)
        return try! JSONEncoder().encode(r)
    }

    @Test("REQ-REG-3 valid remote wins over cached and bundled")
    func remoteWins() {
        let remote = data { $0.updated = "2099-01-01" }
        let cached = data { $0.updated = "2050-01-01" }
        #expect(RegistryValidator.select(remote: remote, cached: cached, bundled: bundled).updated == "2099-01-01")
    }

    @Test("REQ-REG-3 invalid remote falls back to cached, then bundled")
    func fallbackChain() {
        let cached = data { $0.updated = "2050-01-01" }
        #expect(RegistryValidator.select(remote: Data("garbage".utf8), cached: cached, bundled: bundled).updated == "2050-01-01")
        #expect(RegistryValidator.select(remote: nil, cached: Data("x".utf8), bundled: bundled) == bundled)
    }

    @Test("REQ-REG-3 unsupported schemaVersion is rejected")
    func unsupportedSchema() {
        let remote = data { $0.schemaVersion = 99 }
        #expect(throws: ManagerError.registryInvalid) { try RegistryValidator.validate(remote) }
    }

    @Test("REQ-REG-5 duplicate ids make the registry invalid")
    func duplicateIds() {
        let remote = data { $0.apps.append($0.apps[0]) }
        #expect(throws: ManagerError.registryInvalid) { try RegistryValidator.validate(remote) }
    }

    @Test("REQ-REG-3 a valid registry validates")
    func validRegistry() throws {
        #expect(try RegistryValidator.validate(JSONEncoder().encode(bundled)) == bundled)
    }

    @Test("REQ-REG-4 installed app missing from registry stays listed")
    func removedAppStaysListed() {
        let model = MainWindowModel()
        model.setRows(registry: bundled, enabled: ["gridcraft"], removedFromRegistry: ["oldcraft"])
        #expect(model.rowIds == ["gridcraft", "oldcraft"])
        let row = AppRowModel(name: "OldCraft", installed: makeInstalled(url: URL(fileURLWithPath: "/x/Old.app"), version: "1.0.0"),
                              available: makeRelease("2.0.0"), inRegistry: false)
        #expect(row.registryNote == "No longer in registry")
        #expect(!row.visibleButtons.contains(.update))
        #expect(row.visibleButtons.contains(.run) && row.visibleButtons.contains(.uninstall) && row.visibleButtons.contains(.openLocation))
    }
}

struct ReleaseResolutionTests {
    let app = makeApp()
    let good = "gridcraft-0.14.2-macos-universal.dmg"

    @Test("REQ-REG-6 draft and prerelease are ignored")
    func draftAndPrerelease() {
        #expect(throws: ManagerError.releaseUnusable(app: "GridCraft")) {
            try ReleaseResolver.resolve(app: app, json: releaseJSON(tag: "v0.14.2", assets: [good], draft: true))
        }
        #expect(throws: ManagerError.releaseUnusable(app: "GridCraft")) {
            try ReleaseResolver.resolve(app: app, json: releaseJSON(tag: "v0.14.2", assets: [good], prerelease: true))
        }
    }

    @Test("REQ-REG-7 usable release resolves tag version and dmg asset")
    func usable() throws {
        let release = try ReleaseResolver.resolve(app: app, json: releaseJSON(tag: "v0.14.2", assets: ["SHA256SUMS.txt", good]))
        #expect(release.version == AppVersion("0.14.2"))
        #expect(release.dmgName == good)
        #expect(release.checksumURL != nil)
    }

    @Test("REQ-REG-7 tag mismatch, no dmg, or two dmgs are releaseUnusable")
    func unusable() {
        let cases: [Data] = [
            releaseJSON(tag: "nightly", assets: [good]),
            releaseJSON(tag: "v0.14.2", assets: ["gridcraft-0.14.2-linux-x86_64.deb"]),
            releaseJSON(tag: "v0.14.2", assets: [good, good]),
        ]
        for json in cases {
            #expect(throws: ManagerError.releaseUnusable(app: "GridCraft")) { try ReleaseResolver.resolve(app: app, json: json) }
        }
    }

    @Test("REQ-REG-7 ArtCraft's differing naming resolves from the real fixture")
    func artcraftFixture() throws {
        let registry = try loadRegistryFile()
        let art = registry.apps.first { $0.id == "artcraft" }!
        let json = try Data(contentsOf: Repo.fixture("releases/artcraft.json"))
        let release = try ReleaseResolver.resolve(app: art, json: json)
        #expect(release.dmgName.hasSuffix("_universal.dmg"))
        #expect(release.checksumURL == nil)
    }
}

struct VersionTests {
    @Test("REQ-REG-8 versions compare numerically per component")
    func numericCompare() {
        #expect(AppVersion("0.9.0")! < AppVersion("0.10.0")!)
        #expect(AppVersion("1.2.3")! < AppVersion("1.2.4")!)
        #expect(!(AppVersion("1.2.3")! < AppVersion("1.2.3")!))
        #expect(AppVersion("2.0.0")! > AppVersion("1.99.99")!)
        #expect(AppVersion("1.2.3")!.description == "1.2.3")
    }

    @Test("REQ-REG-8 an update needs a strictly greater version; garbage is rejected")
    func strictlyGreater() {
        let row = AppRowModel(name: "GridCraft", installed: makeInstalled(url: URL(fileURLWithPath: "/a/GridCraft.app"), version: "0.14.2"),
                              available: makeRelease("0.14.2"))
        #expect(!row.visibleButtons.contains(.update))
        #expect(AppVersion("not-a-version") == nil)
    }
}

struct FetcherTests {
    let app = makeApp()
    let body = releaseJSON(tag: "v0.14.2", assets: ["gridcraft-0.14.2-macos-universal.dmg", "SHA256SUMS.txt"])

    @Test("REQ-REG-9 sends If-None-Match and treats 304 as notModified")
    func etag() async throws {
        let transport = FakeHTTPTransport { _ in (Data(), 304, [:]) }
        let result = try await GitHubReleaseFetcher(transport: transport, tokens: nil).latestRelease(for: app, etag: "\"abc\"")
        #expect(transport.requests.first?.value(forHTTPHeaderField: "If-None-Match") == "\"abc\"")
        #expect(transport.requests.first?.url == app.apiLatestUrl)
        #expect(result == .notModified)
    }

    @Test("REQ-REG-9 a 200 returns the release and its ETag")
    func okWithEtag() async throws {
        let transport = FakeHTTPTransport { [body] _ in (body, 200, ["ETag": "\"new\""]) }
        let result = try await GitHubReleaseFetcher(transport: transport, tokens: nil).latestRelease(for: app, etag: nil)
        guard case .release(let release, let etag) = result else { Issue.record("expected release"); return }
        #expect(release.version == AppVersion("0.14.2"))
        #expect(etag == "\"new\"")
    }

    @Test("REQ-REG-10 exhausted rate limit throws rateLimited with the reset time")
    func rateLimited() async {
        let reset = Date(timeIntervalSince1970: 2_000_000_000)
        let transport = FakeHTTPTransport { _ in
            (Data(), 403, ["X-RateLimit-Remaining": "0", "X-RateLimit-Reset": "2000000000"])
        }
        await #expect(throws: ManagerError.rateLimited(resetAt: reset)) {
            try await GitHubReleaseFetcher(transport: transport, tokens: nil).latestRelease(for: app, etag: nil)
        }
    }

    @Test("REQ-REG-10 connectivity failure throws offline")
    func offline() async {
        let transport = FakeHTTPTransport { _ in throw URLError(.notConnectedToInternet) }
        await #expect(throws: ManagerError.offline) {
            try await GitHubReleaseFetcher(transport: transport, tokens: nil).latestRelease(for: app, etag: nil)
        }
    }

    @Test("REQ-REG-11 token is sent when available and omitted otherwise")
    func token() async throws {
        let withToken = FakeHTTPTransport { [body] _ in (body, 200, [:]) }
        _ = try await GitHubReleaseFetcher(transport: withToken, tokens: FakeTokenProvider(value: "ghp_x")).latestRelease(for: app, etag: nil)
        #expect(withToken.requests.first?.value(forHTTPHeaderField: "Authorization") == "Bearer ghp_x")
        let without = FakeHTTPTransport { [body] _ in (body, 200, [:]) }
        _ = try await GitHubReleaseFetcher(transport: without, tokens: FakeTokenProvider(value: nil)).latestRelease(for: app, etag: nil)
        #expect(without.requests.first?.value(forHTTPHeaderField: "Authorization") == nil)
    }
}

struct SchedulerTests {
    @Test("REQ-REG-12 checks repeat every 6 hours")
    func interval() {
        #expect(UpdateCoordinator.interval == 6 * 60 * 60)
    }

    @Test("REQ-REG-12 a check does not start while another is in flight")
    func noOverlap() async {
        let coordinator = UpdateCoordinator(fetcher: FakeFetcher(delayNanos: 200_000_000))
        let apps = [makeApp()]
        async let first = coordinator.checkNow(apps: apps)
        try? await Task.sleep(nanoseconds: 50_000_000)
        let second = await coordinator.checkNow(apps: apps)
        #expect(await first == true)
        #expect(second == false)
    }
}

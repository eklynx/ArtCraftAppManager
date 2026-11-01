import AppKit
import Foundation
import Testing
@testable import ArtCraftAppManager

// docs/specs/04-main-window.md (REQ-WIN-25), docs/specs/02-app-registry.md (REQ-REG-13)

private func pngData() -> Data {
    let image = NSImage(size: NSSize(width: 4, height: 4), flipped: false) { rect in NSColor.red.setFill(); rect.fill(); return true }
    let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
    return rep.representation(using: .png, properties: [:])!
}

private func iconApp() -> RegistryApp {
    var app = makeApp()
    app.iconUrl = URL(string: "https://raw.githubusercontent.com/storytold/gridcraft/HEAD/icon.png")
    return app
}

struct IconProviderTests {
    let cache: URL
    init() throws { cache = try makeTempDir("icons") }

    private func provider(_ transport: FakeHTTPTransport, now: @escaping () -> Date = { Date() }) -> GitHubIconProvider {
        GitHubIconProvider(transport: transport, cacheFolder: cache, now: now)
    }

    @Test("REQ-WIN-25 downloads, validates and caches the icon")
    func fetchAndCache() async {
        let transport = FakeHTTPTransport { _ in (pngData(), 200, ["ETag": "\"e1\""]) }
        let data = await provider(transport).icon(for: iconApp())
        #expect(data == pngData())
        #expect(FileManager.default.fileExists(atPath: cache.appendingPathComponent("gridcraft.png").path))
    }

    @Test("REQ-WIN-25 a fresh cached icon is used without touching the network")
    func cacheHit() async {
        _ = await provider(FakeHTTPTransport { _ in (pngData(), 200, [:]) }).icon(for: iconApp())
        let offline = FakeHTTPTransport { _ in throw URLError(.notConnectedToInternet) }
        #expect(await provider(offline).icon(for: iconApp()) == pngData())
        #expect(offline.requests.isEmpty)
    }

    @Test("REQ-WIN-25 after a day the icon is revalidated with its ETag; 304 keeps the cache")
    func revalidate() async {
        let start = Date()
        _ = await provider(FakeHTTPTransport { _ in (pngData(), 200, ["ETag": "\"e1\""]) }, now: { start }).icon(for: iconApp())
        let transport = FakeHTTPTransport { _ in (Data(), 304, [:]) }
        let data = await provider(transport, now: { start.addingTimeInterval(25 * 3600) }).icon(for: iconApp())
        #expect(data == pngData())
        #expect(transport.requests.first?.value(forHTTPHeaderField: "If-None-Match") == "\"e1\"")
    }

    @Test("REQ-WIN-25 offline, 404, non-image and oversize answers give nil and cache nothing")
    func failures() async {
        let cases: [(Data, Int)] = [(Data("nope".utf8), 200), (pngData(), 404), (Data(count: 2_100_000), 200)]
        for (body, status) in cases {
            let transport = FakeHTTPTransport { _ in (body, status, [:]) }
            #expect(await provider(transport).icon(for: iconApp()) == nil)
        }
        let offline = FakeHTTPTransport { _ in throw URLError(.notConnectedToInternet) }
        #expect(await provider(offline).icon(for: iconApp()) == nil)
        #expect(!FileManager.default.fileExists(atPath: cache.appendingPathComponent("gridcraft.png").path))
    }

    @Test("REQ-WIN-25 an App without iconUrl yields nil without any request")
    func noIconUrl() async {
        var app = iconApp(); app.iconUrl = nil
        let transport = FakeHTTPTransport { _ in (pngData(), 200, [:]) }
        #expect(await provider(transport).icon(for: app) == nil)
        #expect(transport.requests.isEmpty)
    }

    @Test("REQ-WIN-25 a failed refresh keeps showing the old cached icon")
    func staleOnFailure() async {
        let start = Date()
        _ = await provider(FakeHTTPTransport { _ in (pngData(), 200, [:]) }, now: { start }).icon(for: iconApp())
        let offline = FakeHTTPTransport { _ in throw URLError(.notConnectedToInternet) }
        #expect(await provider(offline, now: { start.addingTimeInterval(48 * 3600) }).icon(for: iconApp()) == pngData())
    }
}

struct IconChoiceTests {
    @Test("REQ-WIN-25 precedence: installed icon, then cached icon, then placeholder")
    func precedence() {
        #expect(IconChoice.source(installed: true, cached: true) == .installed)
        #expect(IconChoice.source(installed: true, cached: false) == .installed)
        #expect(IconChoice.source(installed: false, cached: true) == .cached)
        #expect(IconChoice.source(installed: false, cached: false) == .placeholder)
    }
}

struct RegistryIconTests {
    @Test("REQ-REG-13 every shipped App has an https raw.githubusercontent.com PNG icon URL")
    func shippedIconUrls() throws {
        for app in try loadRegistryFile().apps {
            let url = try #require(app.iconUrl, "\(app.id) has no iconUrl")
            #expect(url.scheme == "https" && url.host == "raw.githubusercontent.com", "\(app.id)")
            #expect(url.path.hasSuffix(".png"), "\(app.id)")
        }
    }
}

struct FakeIconProviderTests {
    @Test("REQ-WIN-25 an icon provider that has no icon yields nil, so the UI keeps the placeholder")
    func missingIcon() async {
        let fake = FakeIconProvider()
        #expect(await fake.icon(for: makeApp()) == nil)
        fake.icons["gridcraft"] = Data("x".utf8)
        #expect(await fake.icon(for: makeApp()) != nil)
        #expect(fake.requested == ["gridcraft", "gridcraft"])
    }
}

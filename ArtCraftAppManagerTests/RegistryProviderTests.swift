import Foundation
import Testing
@testable import ArtCraftAppManager

// docs/specs/02-app-registry.md — the production registry provider, driven through the HTTPTransport seam.

struct RegistryProviderTests {
    let bundled = try! loadRegistryFile()

    private func provider(_ transport: FakeHTTPTransport, state: InMemoryStateStore = InMemoryStateStore()) -> BundledRemoteRegistryProvider {
        BundledRemoteRegistryProvider(bundled: bundled, transport: transport, state: state)
    }

    @Test("REQ-REG-2 a valid remote registry is fetched, cached and then used")
    func refreshCaches() async throws {
        var remote = bundled; remote.updated = "2099-01-01"
        let body = try JSONEncoder().encode(remote)
        let transport = FakeHTTPTransport { _ in (body, 200, [:]) }
        let state = InMemoryStateStore()
        let sut = provider(transport, state: state)
        #expect(await sut.current() == bundled)
        await sut.refresh()
        #expect(transport.requests.first?.url == RegistryLocations.remoteURL)
        #expect(await sut.current().updated == "2099-01-01")
        #expect(state.state.cachedRegistry != nil)
    }

    @Test("REQ-REG-3 invalid or unreachable remote leaves the bundled registry in effect")
    func refreshFallsBack() async {
        let garbage = FakeHTTPTransport { _ in (Data("nope".utf8), 200, [:]) }
        let sutA = provider(garbage)
        await sutA.refresh()
        #expect(await sutA.current() == bundled)
        let offline = FakeHTTPTransport { _ in throw URLError(.notConnectedToInternet) }
        let sutB = provider(offline)
        await sutB.refresh()
        #expect(await sutB.current() == bundled)
        let notFound = FakeHTTPTransport { _ in (Data(), 404, [:]) }
        let sutC = provider(notFound)
        await sutC.refresh()
        #expect(await sutC.current() == bundled)
    }

    @Test("REQ-REG-11 the registry refresh sends the GitHub token when one is available")
    func refreshUsesToken() async throws {
        let transport = FakeHTTPTransport { _ in (Data(), 404, [:]) }
        let sut = BundledRemoteRegistryProvider(bundled: bundled, transport: transport, state: InMemoryStateStore(),
                                                tokens: FakeTokenProvider(value: "ghp_x"))
        await sut.refresh()
        #expect(transport.requests.first?.value(forHTTPHeaderField: "Authorization") == "Bearer ghp_x")
    }

    @Test("REQ-REG-1 the registry bundled in the app loads and validates")
    func loadsBundledCopy() throws {
        #expect(try BundledRemoteRegistryProvider.loadBundled().apps.count == 14)
    }
}

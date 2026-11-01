import Foundation
import Testing
@testable import ArtCraftAppManager

// docs/specs/03-install-update.md — Detection, and docs/specs/01-overview.md goals

struct DetectionTests {
    let app = makeApp()

    private func locator(folders: [URL] = [], recorded: [String: URL] = [:], spotlight: [URL] = [], running: Set<String> = []) -> DiskAppLocator {
        DiskAppLocator(searchFolders: folders, recordedPaths: recorded, bundleIDLookup: { _ in spotlight }, runningBundleIDs: { running })
    }

    @Test("REQ-INS-1 / REQ-OVR-2 a hand-installed copy found by bundle ID is detected anywhere")
    func detectsByBundleId() throws {
        let volume = try makeTempDir("volume")
        let bundle = try makeStubApp(in: volume, version: "0.13.0")
        let found = locator(spotlight: [bundle]).installedCopies(of: app)
        #expect(found.map(\.url) == [bundle])
        #expect(found.first?.version == AppVersion("0.13.0"))
    }

    @Test("REQ-INS-1 the recorded path is used when Spotlight finds nothing")
    func detectsByRecordedPath() throws {
        let folder = try makeTempDir("rec")
        let bundle = try makeStubApp(in: folder, version: "0.12.0")
        let found = locator(recorded: [app.id: bundle]).installedCopies(of: app)
        #expect(found.map(\.url) == [bundle])
    }

    @Test("REQ-INS-2 with a null bundleId, falls back to appBundleName in the known folders")
    func fallbackByName() throws {
        let folder = try makeTempDir("known")
        let bundle = try makeStubApp(in: folder, version: "0.11.0")
        let noId = makeApp(bundleId: nil)
        // Compare paths: URL equality is sensitive to a trailing slash once the directory exists.
        #expect(locator(folders: [folder]).installedCopies(of: noId).map(\.url.path) == [bundle.path])
    }

    @Test("REQ-INS-3 prefers the recorded path, else the highest version")
    func resolvesDuplicates() throws {
        let a = makeInstalled(url: URL(fileURLWithPath: "/Volumes/A/GridCraft.app"), version: "0.10.0")
        let b = makeInstalled(url: URL(fileURLWithPath: "/Volumes/B/GridCraft.app"), version: "0.14.2")
        let byRecord = InstallResolver.resolve(copies: [a, b], recordedPath: a.url)
        #expect(byRecord?.shown == a && byRecord?.others == [b])
        let byVersion = InstallResolver.resolve(copies: [a, b], recordedPath: nil)
        #expect(byVersion?.shown == b)
        #expect(InstallResolver.resolve(copies: [], recordedPath: nil) == nil)
        let note = ManagerError.duplicateCopy(app: "GridCraft", path: a.url.path)
        #expect(note.statusText?.contains(a.url.path) == true)
    }

    @Test("REQ-INS-4 installed version is CFBundleShortVersionString")
    func readsVersion() throws {
        let folder = try makeTempDir("ver")
        let bundle = try makeStubApp(in: folder, version: "3.4.5")
        #expect(locator(spotlight: [bundle]).installedCopies(of: app).first?.version == AppVersion("3.4.5"))
    }

    @Test("REQ-INS-4 running state comes from running bundle IDs")
    func runningState() throws {
        let folder = try makeTempDir("run")
        let bundle = try makeStubApp(in: folder, version: "1.0.0")
        let installed = makeInstalled(url: bundle, version: "1.0.0")
        #expect(locator(running: [app.bundleId!]).isRunning(installed))
        #expect(!locator(running: []).isRunning(installed))
    }
}

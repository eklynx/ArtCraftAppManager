import Foundation
import Testing
@testable import ArtCraftAppManager

// docs/specs/08-architecture.md, 09-test-plan.md, 01-overview.md

private func text(_ url: URL) -> String { (try? String(contentsOf: url, encoding: .utf8)) ?? "" }

struct ArchitectureTests {
    private var appFiles: [URL] { Repo.swiftFiles(in: Repo.appSources) }

    @Test("REQ-ARC-1 UI code depends on protocols, not concrete infrastructure types")
    func uiUsesProtocols() {
        let banned = ["DiskInstaller", "GitHubReleaseFetcher", "JSONStateStore", "UserDefaultsSettingsStore", "DiskAppLocator", "HdiutilMounter"]
        for file in appFiles where file.path.contains("/UI/") {
            for name in banned { #expect(!text(file).contains(name), "\(file.lastPathComponent) references \(name)") }
        }
    }

    @Test("REQ-ARC-2 every protocol's doc comment has Happy path and Errors sections")
    func protocolDocs() {
        for file in appFiles {
            let lines = text(file).components(separatedBy: "\n")
            for (i, line) in lines.enumerated() where line.hasPrefix("protocol ") {
                var doc = ""
                var j = i - 1
                while j >= 0, lines[j].hasPrefix("///") { doc = lines[j] + "\n" + doc; j -= 1 }
                let name = line.split(separator: " ")[1]
                #expect(doc.contains("Happy path"), "\(name) lacks 'Happy path'")
                #expect(doc.contains("Errors") || doc.contains("errors") || doc.contains("Errors:"), "\(name) lacks errors section")
            }
        }
    }

    @Test("REQ-ARC-3 every protocol has a fake in the test target")
    func fakesExist() {
        let protocols = appFiles.flatMap { f in
            text(f).components(separatedBy: "\n").filter { $0.hasPrefix("protocol ") }.map { String($0.split(separator: " ")[1]).trimmingCharacters(in: CharacterSet(charactersIn: ":{")) }
        }
        let tests = Repo.swiftFiles(in: Repo.unitTests).map(text).joined(separator: "\n")
        for p in protocols { #expect(tests.contains(": \(p)"), "no test fake conforms to \(p)") }
    }

    @Test("REQ-ARC-8 every file declaring a protocol starts with a SOURCE OF TRUTH header")
    func sourceOfTruthHeaders() {
        for file in appFiles where text(file).contains("\nprotocol ") || text(file).hasPrefix("protocol ") {
            #expect(text(file).hasPrefix("// SOURCE OF TRUTH"), "\(file.lastPathComponent) lacks the header")
        }
    }

    @Test("REQ-ARC-5 App Sandbox is off and Hardened Runtime is on (ADR 0001)")
    func sandboxOff() {
        let pbx = text(Repo.pbxproj)
        #expect(!pbx.contains("ENABLE_APP_SANDBOX = YES"))
        #expect(pbx.contains("ENABLE_HARDENED_RUNTIME = YES"))
    }

    @Test("REQ-ARC-7 apps.json is referenced from the Xcode project as a bundle resource (single source)")
    func singleSourceResource() {
        let pbx = text(Repo.pbxproj)
        #expect(pbx.contains("apps.json"))
        #expect(!FileManager.default.fileExists(atPath: Repo.appSources.appendingPathComponent("apps.json").path))
    }

    @Test("REQ-OVR-4 the app list lives in the registry, not in code")
    func noHardcodedApps() throws {
        let ids = try loadRegistryFile().apps.map(\.id)
        for file in appFiles {
            let t = text(file).lowercased()
            for id in ids { #expect(!t.contains("\"\(id)\""), "\(file.lastPathComponent) hard-codes \(id)") }
        }
    }
}

struct TestSuiteRulesTests {
    @Test("REQ-TST-2 unit tests use Swift Testing, not XCTest")
    func swiftTesting() {
        for file in Repo.swiftFiles(in: Repo.unitTests) { #expect(!text(file).contains("import " + "XCTest"), "\(file.lastPathComponent)") }
        for file in Repo.swiftFiles(in: Repo.uiTests) { #expect(text(file).contains("import " + "XCTest")) }
    }

    @Test("REQ-TST-3 unit tests are hermetic: no real network, Trash or shared URLSession")
    func hermetic() {
        let banned = ["URLSession.shared", "NSWorkspace.shared.recycle", "trashItem(", "https://api.github.com/repos/storytold/gridcraft/releases/latest\")!.dataTask"]
        for file in Repo.swiftFiles(in: Repo.unitTests) where file.lastPathComponent != "ArchitectureTests.swift" {
            for b in banned { #expect(!text(file).contains(b), "\(file.lastPathComponent) uses \(b)") }
        }
    }
}

struct DiskImageIntegrationTests {
    @Test("REQ-TST-5 a real fixture dmg built with hdiutil mounts, exposes the stub app, and unmounts")
    func realDmg() throws {
        let work = try makeTempDir("dmg")
        let src = work.appendingPathComponent("src")
        try FileManager.default.createDirectory(at: src, withIntermediateDirectories: true)
        try makeStubApp(in: src, version: "9.9.9")
        let dmg = work.appendingPathComponent("fixture.dmg")
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        p.arguments = ["create", "-quiet", "-volname", "Fixture", "-srcfolder", src.path, "-format", "UDZO", dmg.path]
        try p.run(); p.waitUntilExit()
        #expect(p.terminationStatus == 0)
        let mounter = HdiutilMounter()
        let mountPoint = try mounter.mount(dmg, app: "GridCraft")
        defer { mounter.unmount(mountPoint) }
        #expect(installedVersion(at: mountPoint.appendingPathComponent("GridCraft.app")) == "9.9.9")
    }
}

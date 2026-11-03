import Foundation
import Testing
@testable import ArtCraftAppManager

// docs/specs/10-manager-update.md (REQ-UPD-1…9)
struct ManagerUpdateTests {
    @Test("REQ-UPD-2 channels are cumulative and release is the default")
    func channels() {
        #expect(ManagerUpdateChannel.release.sparkleChannels.isEmpty)
        #expect(ManagerUpdateChannel.prerelease.sparkleChannels == ["prerelease"])
        #expect(ManagerUpdateChannel.nightly.sparkleChannels == ["prerelease", "nightly"])
        #expect(UserDefaultsSettingsStore(defaults: freshDefaults()).managerUpdateChannel == .release)
    }

    @Test("REQ-UPD-2 / REQ-UPD-4 channel and automatic check persist; automatic check defaults on")
    func settingsPersist() {
        let defaults = freshDefaults()
        let store = UserDefaultsSettingsStore(defaults: defaults)
        #expect(store.managerAutoCheck)
        store.managerAutoCheck = false
        store.managerUpdateChannel = .nightly
        let reread = UserDefaultsSettingsStore(defaults: defaults)
        #expect(!reread.managerAutoCheck)
        #expect(reread.managerUpdateChannel == .nightly)
    }

    @MainActor
    @Test("REQ-UPD-6 the disabled updater never starts a check and records requests")
    func disabledUpdater() {
        let updater = DisabledManagerUpdater()
        #expect(!updater.canCheckForUpdates)
        updater.checkForUpdates()
        #expect(updater.checkCount == 1)
    }

    @MainActor
    @Test("REQ-UPD-3 Check for Updates… sits under About in the app menu and calls the updater")
    func menuItem() throws {
        let app = try String(contentsOf: Repo.root.appendingPathComponent("ArtCraftAppManager/ArtCraftAppManagerApp.swift"), encoding: .utf8)
        let about = try #require(app.range(of: "Button(\"About ArtCraft Application Manager\")"))
        let check = try #require(app.range(of: "Button(\"Check for Updates…\") { model.managerUpdater.checkForUpdates() }"))
        #expect(about.lowerBound < check.lowerBound)
        let updater = FakeManagerUpdater()
        updater.checkForUpdates()
        #expect(updater.checks == 1)
    }

    @Test("REQ-UPD-1 / REQ-UPD-9 Info.plist carries the Feed URL, public key and automatic checks")
    func plistKeys() throws {
        let data = try Data(contentsOf: Repo.root.appendingPathComponent("Config/Sparkle-Info.plist"))
        let plist = try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        #expect(plist["SUFeedURL"] as? String == "https://eklynx.github.io/ArtCraftAppManager/appcast.xml")
        #expect((plist["SUPublicEDKey"] as? String)?.count == 44)
        #expect(plist["SUEnableAutomaticChecks"] as? Bool == true)
    }

    @Test("REQ-UPD-7 the appcast workflow runs after Release and Nightly Build, signs with the secret and deploys to Pages")
    func appcastWorkflow() throws {
        let text = try String(contentsOf: Repo.root.appendingPathComponent(".github/workflows/appcast.yml"), encoding: .utf8)
        #expect(text.contains("workflow_run:"))
        #expect(text.contains("workflows: [Release, Nightly Build]"))
        #expect(text.contains("workflow_dispatch:"))
        #expect(text.contains("secrets.SPARKLE_ED_PRIVATE_KEY"))
        #expect(text.contains("actions/deploy-pages"))
        #expect(text.contains("pages: write"))
    }

    @Test("REQ-UPD-5 CI uses a UTC timestamp as the build number")
    func buildNumber() throws {
        let text = try String(contentsOf: Repo.root.appendingPathComponent(".github/workflows/package.yml"), encoding: .utf8)
        #expect(text.contains("date -u +%Y%m%d%H%M%S"))
        #expect(text.contains("CURRENT_PROJECT_VERSION='${{ steps.name.outputs.build }}'"))
    }

    @Test("REQ-UPD-7 the appcast script passes its own Python tests")
    func appcastScript() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [Repo.root.appendingPathComponent("scripts/tests/build-appcast-tests.py").path]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0, "\(String(decoding: data, as: UTF8.self))")
    }

    @Test("REQ-UPD-8 no private key material is committed")
    func noPrivateKeyInRepo() throws {
        let plist = try String(contentsOf: Repo.root.appendingPathComponent("Config/Sparkle-Info.plist"), encoding: .utf8)
        #expect(!plist.localizedCaseInsensitiveContains("private"))
        let doc = try String(contentsOf: Repo.root.appendingPathComponent("docs/specs/10-manager-update.md"), encoding: .utf8)
        #expect(doc.contains("Dev-ArtCraftAppManager"))
    }

    private func freshDefaults() -> UserDefaults {
        let name = "mgr-update-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}

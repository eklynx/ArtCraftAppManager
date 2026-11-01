import Foundation
import Testing
@testable import ArtCraftAppManager

// docs/specs/04-main-window.md (REQ-WIN-22…24)

private let noon = Date(timeIntervalSince1970: 1_760_000_000)  // 9 Oct 2025, midday UTC

private func installedRow(running: Bool = false, progress: Double? = nil, updateTo: String? = nil,
                          managerDate: Date? = nil, released: Date? = nil, fileDate: Date? = nil,
                          inRegistry: Bool = true) -> AppRowModel {
    AppRowModel(name: "GridCraft", installed: makeInstalled(url: URL(fileURLWithPath: "/Volumes/X/GridCraft.app"), version: "1.0.0"),
                available: updateTo.map { makeRelease($0) }, isRunning: running, progress: progress, inRegistry: inRegistry,
                installedByManagerAt: managerDate, releasedAt: released, fileDate: fileDate)
}

struct RowContextMenuTests {
    @Test("REQ-WIN-22 installed row lists every action in the fixed order")
    func fixedOrder() {
        #expect(installedRow().menuActions == [.run, .update, .openLocation, .uninstall, .cancel, .copyPath, .openReleasesPage])
    }

    @Test("REQ-WIN-22 not-installed row leads with Install and disables the rest")
    func notInstalled() {
        let row = AppRowModel(name: "GridCraft")
        #expect(row.menuActions.first == .install)
        #expect(row.enabledMenuActions == [.install, .openReleasesPage])
    }

    @Test("REQ-WIN-22 entries that do not apply are disabled, not hidden")
    func disabledNotHidden() {
        let row = installedRow()
        #expect(row.menuActions.contains(.update) && !row.enabledMenuActions.contains(.update))
        #expect(row.enabledMenuActions == [.run, .openLocation, .uninstall, .copyPath, .openReleasesPage])
        #expect(installedRow(updateTo: "1.1.0").enabledMenuActions.contains(.update))
    }

    @Test("REQ-WIN-22 a row removed from the registry shows only four entries")
    func removedFromRegistry() {
        let row = installedRow(updateTo: "2.0.0", inRegistry: false)
        #expect(row.menuActions == [.run, .openLocation, .uninstall, .copyPath])
        #expect(row.enabledMenuActions == Set(row.menuActions))
    }

    @Test("REQ-WIN-22 only Cancel is enabled while downloading")
    func busy() {
        #expect(installedRow(progress: 0.4).enabledMenuActions == [.cancel])
        #expect(installedRow(progress: 1).enabledMenuActions == [])
    }

    @Test("REQ-WIN-24 menu and buttons agree for every row state")
    func parity() {
        let rows = [installedRow(), installedRow(running: true, updateTo: "1.1.0"), installedRow(updateTo: "1.1.0"),
                    installedRow(progress: 0.5), AppRowModel(name: "GridCraft"), installedRow(inRegistry: false)]
        let pairs: [(RowButton, RowAction)] = [(.install, .install), (.run, .run), (.update, .update), (.openLocation, .openLocation),
                                               (.uninstall, .uninstall), (.cancel, .cancel)]
        for row in rows {
            for (button, action) in pairs {
                #expect(row.enabledButtons.contains(button) == row.enabledMenuActions.contains(action), "\(button)")
            }
        }
    }

    @Test("REQ-WIN-23 two info lines: Manager install date and release date")
    func infoLines() {
        let lines = installedRow(managerDate: noon, released: noon).infoLines
        #expect(lines == ["Updated by Manager: \(RowDateText.format(noon))", "Released: \(RowDateText.format(noon))"])
    }

    @Test("REQ-WIN-23 unknown dates fall back to the wording in the spec")
    func fallbacks() {
        #expect(installedRow(fileDate: noon).infoLines == ["Not installed by Manager", "File date: \(RowDateText.format(noon))"])
        #expect(installedRow().infoLines == ["Not installed by Manager", "Released: unknown"])
    }

    @Test("REQ-WIN-23 not-installed row shows a single line")
    func notInstalledInfo() {
        #expect(AppRowModel(name: "GridCraft").infoLines == ["Not installed"])
    }

    @Test("REQ-WIN-23 dates are formatted d MMM yyyy")
    func format() {
        let parts = DateComponents(calendar: Calendar.current, year: 2026, month: 10, day: 3, hour: 12)
        #expect(RowDateText.format(parts.date!) == "3 Oct 2026")
    }
}

struct InstallStampTests {
    @Test("REQ-WIN-23 release publish date is parsed from published_at")
    func publishedAt() throws {
        let obj: [String: Any] = ["tag_name": "v0.14.2", "draft": false, "prerelease": false, "published_at": "2026-10-03T12:00:00Z",
                                  "assets": [["name": "gridcraft-0.14.2-macos-universal.dmg", "browser_download_url": "https://example.invalid/a.dmg"]]]
        let release = try ReleaseResolver.resolve(app: makeApp(), json: JSONSerialization.data(withJSONObject: obj))
        #expect(release.publishedAt == ISO8601DateFormatter().date(from: "2026-10-03T12:00:00Z"))
        let without = try ReleaseResolver.resolve(app: makeApp(), json: releaseJSON(tag: "v0.14.2", assets: ["gridcraft-0.14.2-macos-universal.dmg"]))
        #expect(without.publishedAt == nil)
    }

    @Test("REQ-WIN-23 / REQ-ARC-4 dates are stored per app and version and round-trip; old state files still load")
    func stateStamps() throws {
        let url = try makeTempDir("stamps").appendingPathComponent("state.json")
        var state = ManagerState()
        state.installDates[ManagerState.stampKey(appId: "gridcraft", version: "1.0.0")] = noon
        state.publishDates[ManagerState.stampKey(appId: "gridcraft", version: "1.0.0")] = noon
        try JSONStateStore(url: url).save(state)
        #expect(JSONStateStore(url: url).load() == state)
        try Data(#"{"recordedPaths":{"gridcraft":"/x"}}"#.utf8).write(to: url)
        #expect(JSONStateStore(url: url).load().recordedPaths["gridcraft"] == "/x")
    }

    @Test("REQ-WIN-23 installing and updating report the new copy to the recorder")
    func installerReports() async throws {
        let rig = try InstallRig()
        var seen: [String] = []
        var installer = rig.installer
        installer.onInstalled = { installed, release in seen.append("\(installed.appId)|\(release.version)") }
        let installed = try await installer.install(rig.release, app: rig.app, to: rig.installFolder) { _ in }
        #expect(seen == ["gridcraft|0.15.0"])
        _ = installed
    }
}

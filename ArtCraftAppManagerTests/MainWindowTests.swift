import Foundation
import Testing
@testable import ArtCraftAppManager

// docs/specs/04-main-window.md

struct RowModelTests {
    let url = URL(fileURLWithPath: "/Volumes/Second/Apps/GridCraft.app")
    func installed(_ v: String = "1.2.34") -> InstalledApp { makeInstalled(url: url, version: v) }

    @Test("REQ-WIN-2 installed row shows 'Ver: x.y.z' and the install path")
    func installedRow() {
        let row = AppRowModel(name: "GridCraft", installed: installed())
        #expect(row.versionText == "Ver: 1.2.34")
        #expect(row.pathText == "/Volumes/Second/Apps")
    }

    @Test("REQ-WIN-2 / REQ-WIN-4 not-installed row says 'Not installed' and offers only Install")
    func notInstalled() {
        let row = AppRowModel(name: "GridCraft", installed: nil, available: makeRelease("0.14.2"))
        #expect(row.pathText == "Not installed")
        #expect(row.visibleButtons == [.install])
        #expect(row.enabledButtons == [.install])
    }

    @Test("REQ-WIN-3 current app: Run, Open Location, Uninstall visible; Update hidden")
    func currentApp() {
        let row = AppRowModel(name: "GridCraft", installed: installed("0.14.2"), available: makeRelease("0.14.2"))
        #expect(Set(row.visibleButtons) == [.run, .openLocation, .uninstall])
    }

    @Test("REQ-WIN-3 the hide-Update rule is one switch: off keeps Update visible but disabled")
    func provisionalSwitch() {
        let row = AppRowModel(name: "GridCraft", installed: installed("0.14.2"), available: nil, hidesUpdateWhenCurrent: false)
        #expect(row.visibleButtons.contains(.update))
        #expect(!row.enabledButtons.contains(.update))
    }

    @Test("REQ-WIN-13 / REQ-WIN-3 update available shows 'installed → available' and an enabled Update")
    func updateAvailable() {
        let row = AppRowModel(name: "GridCraft", installed: installed("1.2.34"), available: makeRelease("1.3.0"))
        #expect(row.versionText == "Ver: 1.2.34 → 1.3.0")
        #expect(row.visibleButtons.contains(.update) && row.enabledButtons.contains(.update))
    }

    @Test("REQ-WIN-14 / REQ-INS-17 busy row swaps buttons for a progress bar; Cancel only while downloading")
    func busy() {
        let row = AppRowModel(name: "GridCraft", installed: installed(), available: makeRelease("1.3.0"), progress: 0.4)
        #expect(row.showsProgressBar)
        #expect(row.visibleButtons == [.cancel])
        #expect(row.versionText.hasPrefix("Ver: 1.2.34"))
    }

    @Test("REQ-WIN-15 running row: label shown, Update/Uninstall disabled with tooltip, Run enabled")
    func running() {
        let row = AppRowModel(name: "GridCraft", installed: installed("1.2.34"), available: makeRelease("1.3.0"), isRunning: true)
        #expect(row.showsRunningLabel)
        #expect(!row.enabledButtons.contains(.update) && !row.enabledButtons.contains(.uninstall))
        #expect(row.enabledButtons.contains(.run))
        #expect(row.tooltip(for: .update) == "Quit GridCraft to update")
    }

    @Test("REQ-WIN-16 removed-from-registry row has the note and no Update")
    func removedFromRegistry() {
        let row = AppRowModel(name: "OldCraft", installed: installed(), available: makeRelease("9.0.0"), inRegistry: false)
        #expect(row.registryNote == "No longer in registry")
        #expect(!row.visibleButtons.contains(.update))
    }
}

struct WindowModelTests {
    let registry = try! loadRegistryFile()

    @Test("REQ-WIN-1 shows enabled apps in registry order")
    func rowsInOrder() {
        let model = MainWindowModel()
        model.setRows(registry: registry, enabled: ["lightcraft", "artcraft", "gridcraft"], removedFromRegistry: [])
        #expect(model.rowIds == ["artcraft", "gridcraft", "lightcraft"])
    }

    @Test("REQ-WIN-6 empty state when no apps are enabled")
    func emptyState() {
        let model = MainWindowModel()
        model.setRows(registry: registry, enabled: [], removedFromRegistry: [])
        #expect(model.showsEmptyState)
    }

    @Test("REQ-WIN-5 refresh shows a spinner while checking")
    func spinner() async {
        let model = MainWindowModel()
        let during = Box(false)
        await model.refresh { during.value = model.isChecking }
        #expect(during.value)
        #expect(!model.isChecking)
    }

    @Test("REQ-WIN-8 offline keeps the known rows and shows the offline message")
    func offlineKeepsRows() async {
        let model = MainWindowModel()
        model.setRows(registry: registry, enabled: ["gridcraft"], removedFromRegistry: [])
        await model.refresh { throw ManagerError.offline }
        #expect(model.rowIds == ["gridcraft"])
        #expect(model.status.text == "Can't reach GitHub. Showing last known versions.")
    }

    @Test("REQ-WIN-7 status line is cleared by the next success or by a click")
    func statusClears() {
        var line = StatusLine()
        line.show(.offline)
        #expect(line.text != nil)
        line.operationSucceeded()
        #expect(line.text == nil)
        line.show(.offline)
        line.tapped()
        #expect(line.text == nil)
    }
}

struct MenuBarTests {
    let model = MenuBarModel(entries: [
        .init(appId: "gridcraft", name: "GridCraft", installed: AppVersion("0.14.2")!, available: AppVersion("0.15.0")!),
        .init(appId: "deckcraft", name: "DeckCraft", installed: AppVersion("0.13.1")!, available: AppVersion("0.14.0")!),
    ])

    @Test("REQ-WIN-19 badge counts updates; menu lists each app then Check Now, Open Manager, Quit")
    func menu() {
        #expect(model.badgeCount == 2)
        #expect(model.lines == ["GridCraft 0.14.2 → 0.15.0", "DeckCraft 0.13.1 → 0.14.0"])
        #expect(MenuBarModel.fixedItems == ["Check Now", "Open Manager", "Quit"])
    }

    @Test("REQ-WIN-20 clicking an app line scrolls to that app's row")
    func scroll() {
        #expect(model.rowToScroll(forLine: 1) == "deckcraft")
        #expect(model.rowToScroll(forLine: 9) == nil)
    }

    @Test("REQ-WIN-9 / REQ-WIN-10 / REQ-WIN-11 menu bar item and window lifecycle follow Launch at login")
    func lifecycle() {
        #expect(AppLifecyclePolicy.hasMenuBarItem(launchAtLogin: true))
        #expect(!AppLifecyclePolicy.hasMenuBarItem(launchAtLogin: false))
        #expect(!AppLifecyclePolicy.quitsWhenLastWindowCloses(launchAtLogin: true))
        #expect(AppLifecyclePolicy.quitsWhenLastWindowCloses(launchAtLogin: false))
        #expect(!AppLifecyclePolicy.showsWindowOnLaunch(startedByLoginItem: true))
        #expect(AppLifecyclePolicy.showsWindowOnLaunch(startedByLoginItem: false))
    }
}

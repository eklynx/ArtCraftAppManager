import Foundation
import Testing
@testable import ArtCraftAppManager

// docs/specs/05-settings.md — App order (REQ-SET-10, REQ-SET-11, REQ-SET-12)

struct AppOrderTests {
    let registry = try! loadRegistryFile()
    var ids: [String] { registry.apps.map(\.id) }

    @Test("REQ-SET-10 with no saved order the registry order is used")
    func defaultOrder() {
        #expect(AppOrder.ordered(registry.apps, saved: nil).map(\.id) == ids)
        #expect(AppOrder.ordered(registry.apps, saved: []).map(\.id) == ids)
    }

    @Test("REQ-SET-10 a saved order wins; missing apps are appended in registry order; unknown ids are ignored")
    func savedOrder() {
        let saved = ["lightcraft", "ghostcraft", "artcraft"]
        let result = AppOrder.ordered(registry.apps, saved: saved).map(\.id)
        #expect(Array(result.prefix(2)) == ["lightcraft", "artcraft"])
        #expect(Array(result.dropFirst(2)) == ids.filter { $0 != "lightcraft" && $0 != "artcraft" })
        #expect(result.count == ids.count)
    }

    @Test("REQ-SET-10 duplicate ids in a saved order appear once")
    func duplicates() {
        let result = AppOrder.ordered(registry.apps, saved: ["artcraft", "artcraft", "gridcraft"]).map(\.id)
        #expect(result.filter { $0 == "artcraft" }.count == 1)
    }

    @Test("REQ-SET-10 the main window shows enabled apps in the App order, unchecked apps keep their place")
    func windowFollowsOrder() {
        let model = MainWindowModel()
        let order = ["lightcraft", "gridcraft", "artcraft"] + ids.filter { !["lightcraft", "gridcraft", "artcraft"].contains($0) }
        model.setRows(registry: registry, enabled: ["artcraft", "lightcraft", "wordcraft"], removedFromRegistry: ["oldcraft"], order: order)
        #expect(model.rowIds == ["lightcraft", "artcraft", "wordcraft", "oldcraft"])
        // Re-checking gridcraft puts it back where the order says.
        model.setRows(registry: registry, enabled: ["artcraft", "lightcraft", "gridcraft"], removedFromRegistry: [], order: order)
        #expect(model.rowIds == ["lightcraft", "gridcraft", "artcraft"])
    }

    @Test("REQ-SET-10 an order equal to the registry order is stored as unset")
    func storableDefault() {
        #expect(AppOrder.storable(ids, registry: registry.apps) == nil)
        #expect(AppOrder.storable(ids.reversed(), registry: registry.apps) == ids.reversed())
    }

    @Test("REQ-SET-10 the order persists in the settings store")
    func persists() {
        let suite = "acam-test-\(UUID().uuidString)"
        let store = UserDefaultsSettingsStore(defaults: UserDefaults(suiteName: suite)!)
        #expect(store.appOrder == nil)
        store.appOrder = ["b", "a"]
        #expect(store.appOrder == ["b", "a"])
        store.appOrder = nil
        #expect(store.appOrder == nil)
    }

    @Test("REQ-SET-11 dragging moves rows with onMove semantics")
    func dragMoves() {
        let list = ["a", "b", "c", "d"]
        #expect(AppOrder.moved(list, fromOffsets: IndexSet(integer: 0), toOffset: 2) == ["b", "a", "c", "d"])
        #expect(AppOrder.moved(list, fromOffsets: IndexSet(integer: 3), toOffset: 0) == ["d", "a", "b", "c"])
        #expect(AppOrder.moved(list, fromOffsets: IndexSet(integer: 1), toOffset: 4) == ["a", "c", "d", "b"])
        #expect(AppOrder.moved(list, fromOffsets: IndexSet([0, 1]), toOffset: 4) == ["c", "d", "a", "b"])
    }

    @Test("REQ-SET-11 Move Up / Move Down shift one place and stop at the ends")
    func accessibilityMoves() {
        let list = ["a", "b", "c"]
        #expect(AppOrder.shifted(list, id: "b", by: -1) == ["b", "a", "c"])
        #expect(AppOrder.shifted(list, id: "b", by: 1) == ["a", "c", "b"])
        #expect(AppOrder.shifted(list, id: "a", by: -1) == list)
        #expect(AppOrder.shifted(list, id: "c", by: 1) == list)
        #expect(AppOrder.shifted(list, id: "zzz", by: 1) == list)
    }

    @Test("REQ-SET-12 resetting returns to the registry order")
    func reset() {
        let reversed = Array(ids.reversed())
        #expect(AppOrder.storable(reversed, registry: registry.apps) != nil)
        // Reset applies the registry order, which is stored as unset.
        #expect(AppOrder.storable(ids, registry: registry.apps) == nil)
        #expect(AppOrder.ordered(registry.apps, saved: nil).map(\.id) == ids)
    }

    @Test("REQ-SET-10 the menu bar menu lists updates in row order")
    func menuFollowsOrder() {
        let menu = MenuBarModel(entries: [
            .init(appId: "lightcraft", name: "LightCraft", installed: AppVersion("1.0.0")!, available: AppVersion("1.1.0")!),
            .init(appId: "artcraft", name: "ArtCraft", installed: AppVersion("0.1.0")!, available: AppVersion("0.2.0")!),
        ])
        #expect(menu.lines.first?.hasPrefix("LightCraft") == true)
        #expect(menu.rowToScroll(forLine: 1) == "artcraft")
    }
}

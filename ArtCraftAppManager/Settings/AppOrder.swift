import Foundation

/// The user's App order (REQ-SET-10).
enum AppOrder {
    /// Apps in the saved order; unknown ids are ignored and missing apps are appended in registry order.
    static func ordered(_ apps: [RegistryApp], saved: [String]?) -> [RegistryApp] {
        guard let saved, !saved.isEmpty else { return apps }
        let byId = Dictionary(apps.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var seen = Set<String>()
        var result = saved.compactMap { id -> RegistryApp? in
            guard let app = byId[id], seen.insert(id).inserted else { return nil }
            return app
        }
        result += apps.filter { !seen.contains($0.id) }
        return result
    }

    /// Moves the items at `offsets` so they land before the element currently at `destination` (SwiftUI `onMove` semantics).
    static func moved(_ ids: [String], fromOffsets offsets: IndexSet, toOffset destination: Int) -> [String] {
        let moving = offsets.sorted().map { ids[$0] }
        var rest = ids
        for index in offsets.sorted().reversed() { rest.remove(at: index) }
        let insertAt = destination - offsets.filter { $0 < destination }.count
        rest.insert(contentsOf: moving, at: max(0, min(insertAt, rest.count)))
        return rest
    }

    /// Moves one id up (-1) or down (+1); returns the input unchanged at the ends.
    static func shifted(_ ids: [String], id: String, by delta: Int) -> [String] {
        guard let index = ids.firstIndex(of: id), ids.indices.contains(index + delta) else { return ids }
        var result = ids
        result.swapAt(index, index + delta)
        return result
    }

    /// The value to store: nil when the order equals the registry order.
    static func storable(_ ids: [String], registry: [RegistryApp]) -> [String]? {
        ids == registry.map(\.id) ? nil : ids
    }
}

// SOURCE OF TRUTH (for humans and AI agents): the `State` namespace contract.
// Types: ManagerStateStoring, ManagerState.
// Read the doc comments on each protocol (happy path + errors) before calling into this namespace,
// and the governing spec: docs/specs/08-architecture.md (REQ-ARC-4). Other namespaces MUST go through these protocols.

import Foundation

struct ManagerState: Codable, Equatable {
    var recordedPaths: [String: String] = [:]
    var lastSeenVersions: [String: String] = [:]
    /// Keys `"<kind>|<appId>|<version>"` already notified (REQ-NOT-3).
    var notified: Set<String> = []
    var etags: [String: String] = [:]
    var cachedRegistry: Data?
    /// When the Manager installed/updated each version, keyed by `stampKey` (REQ-WIN-23).
    var installDates: [String: Date] = [:]
    /// GitHub publish date of each seen release, keyed by `stampKey` (REQ-WIN-23).
    var publishDates: [String: Date] = [:]

    static func stampKey(appId: String, version: String) -> String { "\(appId)|\(version)" }

    init() {}

    /// Tolerant decoding: state files written before a field existed still load (REQ-ARC-4).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        recordedPaths = try c.decodeIfPresent([String: String].self, forKey: .recordedPaths) ?? [:]
        lastSeenVersions = try c.decodeIfPresent([String: String].self, forKey: .lastSeenVersions) ?? [:]
        notified = try c.decodeIfPresent(Set<String>.self, forKey: .notified) ?? []
        etags = try c.decodeIfPresent([String: String].self, forKey: .etags) ?? [:]
        cachedRegistry = try c.decodeIfPresent(Data.self, forKey: .cachedRegistry)
        installDates = try c.decodeIfPresent([String: Date].self, forKey: .installDates) ?? [:]
        publishDates = try c.decodeIfPresent([String: Date].self, forKey: .publishDates) ?? [:]
    }
}

/// Disposable JSON state file (REQ-ARC-4).
///
/// **Happy path:** `load` returns saved state; `save` persists it atomically.
/// **Errors:** `load` never throws — a missing or corrupt file yields empty state; `save` throws on I/O failure.
protocol ManagerStateStoring: AnyObject {
    func load() -> ManagerState
    func save(_ state: ManagerState) throws
}

final class JSONStateStore: ManagerStateStoring {
    private let url: URL
    init(url: URL) { self.url = url }

    func load() -> ManagerState {
        guard let data = try? Data(contentsOf: url), let state = try? JSONDecoder().decode(ManagerState.self, from: data) else {
            return ManagerState()
        }
        return state
    }

    func save(_ state: ManagerState) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(state).write(to: url, options: .atomic)
    }
}

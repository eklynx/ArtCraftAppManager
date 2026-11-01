import Foundation

struct ManagerState: Codable, Equatable {
    var recordedPaths: [String: String] = [:]
    var lastSeenVersions: [String: String] = [:]
    /// Keys `"<kind>|<appId>|<version>"` already notified (REQ-NOT-3).
    var notified: Set<String> = []
    var etags: [String: String] = [:]
    var cachedRegistry: Data?
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
        // Red: not implemented yet.
        ManagerState()
    }

    func save(_ state: ManagerState) throws {
        // Red: not implemented yet.
    }
}

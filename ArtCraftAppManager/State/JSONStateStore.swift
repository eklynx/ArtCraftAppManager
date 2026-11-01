import Foundation

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

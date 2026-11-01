import Foundation

/// Runs update checks (REQ-REG-12).
actor UpdateCoordinator {
    static let interval: TimeInterval = 6 * 60 * 60

    private let fetcher: ReleaseFetching
    private var isChecking = false
    init(fetcher: ReleaseFetching) { self.fetcher = fetcher }

    /// Checks all given apps. Returns false (and does nothing) if a check is already in flight.
    func checkNow(apps: [RegistryApp]) async -> Bool {
        guard !isChecking else { return false }
        isChecking = true
        defer { isChecking = false }
        for app in apps {
            if Task.isCancelled { break }
            _ = try? await fetcher.latestRelease(for: app, etag: nil)
        }
        return true
    }
}

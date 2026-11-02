import Foundation

/// Calls `onChange` for every launch/quit event until the surrounding task is cancelled (REQ-WIN-27).
struct RunningStateRefresher {
    let observer: RunningAppsObserving

    func run(onChange: () -> Void) async {
        for await _ in observer.changes() {
            if Task.isCancelled { return }
            onChange()
        }
    }
}

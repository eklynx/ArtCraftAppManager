import Foundation
import Testing
@testable import ArtCraftAppManager

// docs/specs/04-main-window.md — REQ-WIN-27

struct RunningStateTests {
    private final class LockedBox: @unchecked Sendable {
        private let lock = NSLock()
        private var count = 0
        init(_ count: Int) { self.count = count }
        var value: Int { lock.withLock { count } }
        func increment() { lock.withLock { count += 1 } }
    }

    @Test("REQ-WIN-27 every launch or quit event triggers a rebuild of the running state")
    func eventsTriggerRefresh() async {
        let observer = FakeRunningAppsObserver()
        let calls = LockedBox(0)
        let task = Task { await RunningStateRefresher(observer: observer).run { calls.increment() } }
        while !observer.isObserving { await Task.yield() }
        observer.emit(); observer.emit(); observer.emit()
        observer.finish()
        await task.value
        #expect(calls.value == 3)
    }

    @Test("REQ-WIN-27 the refresher stops when the observed stream ends")
    func stopsWhenStreamEnds() async {
        let observer = FakeRunningAppsObserver()
        let task = Task { await RunningStateRefresher(observer: observer).run {} }
        while !observer.isObserving { await Task.yield() }
        observer.finish()
        await task.value
    }
}

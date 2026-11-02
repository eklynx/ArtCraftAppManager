import AppKit
import Foundation

/// Reports app launches and quits through NSWorkspace notifications (REQ-WIN-27).
struct WorkspaceRunningAppsObserver: RunningAppsObserving {
    func changes() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let center = NSWorkspace.shared.notificationCenter
            let tokens = [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification].map {
                center.addObserver(forName: $0, object: nil, queue: .main) { _ in continuation.yield() }
            }
            continuation.onTermination = { _ in tokens.forEach(center.removeObserver) }
        }
    }
}

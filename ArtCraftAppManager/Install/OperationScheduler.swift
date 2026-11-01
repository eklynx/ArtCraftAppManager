import CryptoKit
import Foundation

/// Serialises work per App and caps concurrent downloads (REQ-INS-16).
actor OperationScheduler {
    static let maxConcurrentDownloads = 2

    private var busyApps: Set<String> = []
    private var appWaiters: [String: [CheckedContinuation<Void, Never>]] = [:]
    private var activeDownloads = 0
    private var downloadWaiters: [CheckedContinuation<Void, Never>] = []

    func run<T>(appId: String, isDownload: Bool, work: @escaping () async throws -> T) async throws -> T {
        await acquireApp(appId)
        if isDownload { await acquireDownloadSlot() }
        defer {
            if isDownload { releaseDownloadSlot() }
            releaseApp(appId)
        }
        return try await work()
    }

    private func acquireApp(_ id: String) async {
        if busyApps.contains(id) {
            await withCheckedContinuation { appWaiters[id, default: []].append($0) }
        } else {
            busyApps.insert(id)
        }
    }

    private func releaseApp(_ id: String) {
        if var waiters = appWaiters[id], !waiters.isEmpty {
            let next = waiters.removeFirst()
            appWaiters[id] = waiters
            next.resume()  // ownership passes to the next waiter
        } else {
            busyApps.remove(id)
        }
    }

    private func acquireDownloadSlot() async {
        if activeDownloads < Self.maxConcurrentDownloads {
            activeDownloads += 1
        } else {
            await withCheckedContinuation { downloadWaiters.append($0) }
        }
    }

    private func releaseDownloadSlot() {
        if !downloadWaiters.isEmpty {
            downloadWaiters.removeFirst().resume()  // slot passes to the next waiter
        } else {
            activeDownloads -= 1
        }
    }
}

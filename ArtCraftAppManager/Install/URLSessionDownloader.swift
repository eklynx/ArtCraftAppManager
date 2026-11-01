import AppKit
import Foundation

/// Downloads with URLSession, reporting progress and cleaning up on failure (REQ-INS-17).
struct URLSessionDownloader: Downloading {
    func download(from url: URL, to folder: URL, app: String, progress: @escaping (Double) -> Void) async throws -> URL {
        let delegate = ProgressDelegate(progress)
        let temp: URL, response: URLResponse
        do {
            (temp, response) = try await URLSession.shared.download(from: url, delegate: delegate)
        } catch {
            if Task.isCancelled || (error as? URLError)?.code == .cancelled { throw CancellationError() }
            throw ManagerError.offline
        }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            try? FileManager.default.removeItem(at: temp)
            throw ManagerError.releaseUnusable(app: app)
        }
        let destination = folder.appendingPathComponent(url.lastPathComponent)
        do {
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: temp, to: destination)
        } catch let error as CocoaError {
            try? FileManager.default.removeItem(at: temp)
            switch error.code {
            case .fileWriteOutOfSpace: throw ManagerError.diskFull(app: app, folder: folder.path)
            default: throw ManagerError.permissionDenied(folder: folder.path)
            }
        }
        progress(1.0)
        return destination
    }

    private final class ProgressDelegate: NSObject, URLSessionDownloadDelegate {
        let report: (Double) -> Void
        init(_ report: @escaping (Double) -> Void) { self.report = report }
        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                        totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
            guard totalBytesExpectedToWrite > 0 else { return }
            report(min(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite), 0.99))
        }
    }
}

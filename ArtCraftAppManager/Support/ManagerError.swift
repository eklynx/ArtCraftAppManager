import Foundation

/// Typed failure surfaced to the status line. Catalogue and wording: docs/specs/07-errors-and-status.md.
enum ManagerError: Error, Equatable {
    enum Operation: Equatable { case update, uninstall }

    case offline
    case rateLimited(resetAt: Date)
    case releaseUnusable(app: String)
    case checksumMismatch(app: String)
    case diskFull(app: String, folder: String)
    case permissionDenied(folder: String)
    case folderMissing(folder: String)
    case mountFailed(app: String)
    case bundleMissing(app: String)
    case destinationExists(app: String, folder: String)
    case appRunning(app: String, operation: Operation)
    case swapFailed(app: String)
    case loginItemFailed
    case registryInvalid
    case duplicateCopy(app: String, path: String)

    /// Stable machine-readable code (REQ-ERR-1).
    var code: String {
        switch self {
        case .offline: "offline"
        case .rateLimited: "rateLimited"
        case .releaseUnusable: "releaseUnusable"
        case .checksumMismatch: "checksumMismatch"
        case .diskFull: "diskFull"
        case .permissionDenied: "permissionDenied"
        case .folderMissing: "folderMissing"
        case .mountFailed: "mountFailed"
        case .bundleMissing: "bundleMissing"
        case .destinationExists: "destinationExists"
        case .appRunning: "appRunning"
        case .swapFailed: "swapFailed"
        case .loginItemFailed: "loginItemFailed"
        case .registryInvalid: "registryInvalid"
        case .duplicateCopy: "duplicateCopy"
        }
    }

    /// Status-line text, or nil when the error is silent (logged only).
    var statusText: String? {
        switch self {
        case .offline: "Can't reach GitHub. Showing last known versions."
        case .rateLimited(let resetAt): "GitHub rate limit reached. Checking again at \(resetAt.formatted(date: .omitted, time: .shortened))."
        case .releaseUnusable(let app): "\(app): latest release has no usable macOS download."
        case .checksumMismatch(let app): "\(app): download failed verification and was discarded."
        case .diskFull(let app, let folder): "Not enough space in \(folder) for \(app)."
        case .permissionDenied(let folder): "Can't write to \(folder)."
        case .folderMissing(let folder): "\(folder) is not available. Is the drive connected?"
        case .mountFailed(let app): "\(app): couldn't open the downloaded disk image."
        case .bundleMissing(let app): "\(app): the disk image didn't contain \(app).app."
        case .destinationExists(let app, let folder): "\(folder)/\(app).app already exists."
        case .appRunning(let app, .update): "Quit \(app) to update."
        case .appRunning(let app, .uninstall): "Quit \(app) to uninstall."
        case .swapFailed(let app): "\(app): update failed; the previous version was kept."
        case .loginItemFailed: "Couldn't enable launch at login."
        case .registryInvalid: nil
        case .duplicateCopy(let app, let path): "Another copy of \(app) exists at \(path)."
        }
    }
}

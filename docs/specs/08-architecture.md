# 08 — Architecture (`ARC`)

Code is grouped by idea into folders/namespaces. Modules talk to each other only through the protocols below; each protocol's doc comment MUST describe happy path and error cases, so agents can use the protocol as the reference for its module.

```
ArtCraftAppManager/
  Registry/       AppRegistryProviding   – load/refresh/validate apps.json
  Releases/       ReleaseFetching        – GitHub latest-release lookup, ETag, rate limit
  Detection/      InstalledAppLocating   – find installed copies, versions, running state
  Install/        InstallationManaging   – download, verify, mount, copy, swap, trash
  Settings/       SettingsStoring        – UserDefaults-backed settings
  Notifications/  UpdateNotifying        – post/handle notifications
  State/          ManagerStateStoring    – JSON state file
  UI/             SwiftUI views + view models (depend only on protocols)
```

## Requirements
- **REQ-ARC-1** Cross-module calls use the protocols above; concrete types are wired in one composition root (`ArtCraftAppManagerApp`).
- **REQ-ARC-2** Each protocol has a doc comment with **Happy path** and **Errors** sections listing `ManagerError` codes ([07](07-errors-and-status.md)).
- **REQ-ARC-3** Every protocol has an in-memory fake in the test target; no unit test touches the network, real volumes, or the real Trash.
- **REQ-ARC-4** The state file `~/Library/Application Support/ArtCraftAppManager/state.json` holds recorded install paths, last-seen versions, notified versions (REQ-NOT-3), ETags and the cached registry. It is disposable: deleting it MUST NOT lose user settings (they are in `UserDefaults`) and detection rebuilds the rest.
- **REQ-ARC-5** **App Sandbox is disabled** ([ADR 0001](../adr/0001-sandbox-and-install-strategy.md)): the Manager must write to arbitrary volumes, mount DMGs and replace apps. The target is signed with Developer ID or ad-hoc; Hardened Runtime on.
- **REQ-ARC-6** Long operations are `async` and cancellable; UI state changes occur on the main actor.
- **REQ-ARC-7** The registry's bundled copy is added to the app target as a resource from `docs/registry/apps.json` (single source; no duplicate file).

## Protocol sketches (informative)
```swift
protocol ReleaseFetching {
    /// Happy path: returns the latest usable Release for `app`, or `.notModified` on HTTP 304.
    /// Errors: .offline, .rateLimited(resetAt), .releaseUnusable
    func latestRelease(for app: RegistryApp, etag: String?) async throws -> ReleaseResult
}
protocol InstallationManaging {
    /// Happy path: installs or updates and returns the new InstalledApp.
    /// Errors: .checksumMismatch, .diskFull, .permissionDenied, .mountFailed, .bundleMissing,
    ///         .destinationExists, .appRunning, .swapFailed
    func install(_ release: Release, for app: RegistryApp, to folder: URL) async throws -> InstalledApp
    func update(_ installed: InstalledApp, to release: Release) async throws -> InstalledApp
    func uninstall(_ installed: InstalledApp) async throws
}
```

# 07 — Errors and Status Text (`ERR`)

- **REQ-ERR-1** Every failure surfaces as a typed `ManagerError` with a stable `code`, a user-facing message for the status line, and a `recovery` hint.
- **REQ-ERR-2** The status line shows one message (the latest); all messages are also written to the unified log (`os.Logger`, subsystem `com.eklynx.ArtCraftAppManager`).
- **REQ-ERR-3** Errors are per-App where possible; one App's failure MUST NOT block other Apps.

| Code | Status text (`<App>`, `<folder>` substituted) | Recovery |
|---|---|---|
| `offline` | "Can't reach GitHub. Showing last known versions." | Retry on next check |
| `rateLimited` | "GitHub rate limit reached. Checking again at <time>." | Wait / add token |
| `releaseUnusable` | "<App>: latest release has no usable macOS download." | None until a new release |
| `checksumMismatch` | "<App>: download failed verification and was discarded." | User retries |
| `diskFull` | "Not enough space in <folder> for <App>." | Free space / change folder |
| `permissionDenied` | "Can't write to <folder>." | Choose another folder |
| `folderMissing` | "<folder> is not available. Is the drive connected?" | Reconnect / change |
| `mountFailed` | "<App>: couldn't open the downloaded disk image." | Retry |
| `bundleMissing` | "<App>: the disk image didn't contain <App>.app." | Report upstream |
| `destinationExists` | "<folder>/<App>.app already exists." | Choose another folder |
| `appRunning` | "Quit <App> to update." (uninstall: "Quit <App> to uninstall.") | Quit the App |
| `swapFailed` | "<App>: update failed; the previous version was kept." | Retry |
| `loginItemFailed` | "Couldn't enable launch at login." | Approve in System Settings |
| `registryInvalid` | (silent; logged) fallback per REQ-REG-3 | – |
| `duplicateCopy` | "Another copy of <App> exists at <path>." (informational) | – |

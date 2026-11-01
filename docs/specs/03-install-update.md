# 03 — Install, Update, Uninstall (`INS`)

## Detection
- **REQ-INS-1** An App is *installed* if a bundle with its `bundleId` exists on a mounted local volume (found via LaunchServices/Spotlight), or at the path recorded in the state file. Hand-installed copies are detected automatically.
- **REQ-INS-2** If `bundleId` is null in the registry, detection falls back to the recorded path and the `appBundleName` in the Default Install Location and `/Applications` (all 14 registry entries currently have a `bundleId`).
- **REQ-INS-3** If several copies exist, the row shows the recorded path, else the copy with the highest version; the status line notes that another copy exists. Update, Uninstall, Run and Open Location act only on the shown copy.
- **REQ-INS-4** Installed version is the bundle's `CFBundleShortVersionString`. State is rebuilt from detection if the state file is missing or corrupt.

## Install (App not installed)
1. User clicks Install; a folder picker opens, prefilled with the Default Install Location.
2. Download the DMG into the Download Location.
3. If `checksumAsset` is set and present in the release, verify SHA-256; otherwise skip.
4. Mount read-only with no Finder window, locate `appBundleName`, copy to `<chosen>/<appBundleName>`.
5. Unmount, delete the DMG, record the path.

- **REQ-INS-5** Install MUST fail with `destinationExists` if the target `.app` already exists and is not the detected copy.
- **REQ-INS-6** On checksum mismatch the DMG MUST be deleted and error `checksumMismatch` shown; nothing is installed.
- **REQ-INS-7** The DMG MUST always be unmounted, including on failure.
- **REQ-INS-8** Quarantine is left as set by the download so Gatekeeper behaves as for a normal download. The Manager MUST NOT strip it.

## Update (App installed, newer Release)
- **REQ-INS-9** Updates install at the shown copy's existing location, never the Default Install Location.
- **REQ-INS-10** Safe replace: copy the new `.app` next to the old one under a temporary name, verify it opens as a bundle with the expected `bundleId`, then swap and move the old one to the Trash. Any failure before the swap leaves the old App untouched; a failure during the swap restores it.
- **REQ-INS-11** If the App is running, Update is blocked: the Update button is disabled-with-reason and a manual attempt shows "Quit <App> to update". The Manager MUST NEVER quit an App.
- **REQ-INS-12** The DMG is deleted after a successful install. A downloaded-but-not-installed DMG is kept in the Download Location; clicking Update reuses it if its checksum still verifies.
- **REQ-INS-13** If the location is not writable: error `permissionDenied` naming the folder.

## Uninstall, Run, Open Location
- **REQ-INS-14** Uninstall shows a confirmation that user data and preferences are kept, then moves the `.app` to the Trash. Blocked while the App is running (message as REQ-INS-11).
- **REQ-INS-15** Run launches the shown copy via `NSWorkspace`. Open Location reveals it in Finder.
- **REQ-INS-16** Operations on one App are serialised; different Apps may run concurrently (max 2 downloads at once).
- **REQ-INS-17** Progress (download %, then "Installing…") is shown on the row; the row's buttons are disabled while busy, with a Cancel for the download phase. Cancel deletes the partial file.

## Error cases
Disk full → `diskFull`; DMG won't mount → `mountFailed`; no `.app` in DMG → `bundleMissing`; offline → `offline`. All in [07](07-errors-and-status.md).

# 05 — Settings (`SET`)

Settings live in a standard macOS Settings window (⌘,) and are persisted in `UserDefaults`.

| # | Setting | Key | Type | Default |
|---|---|---|---|---|
| 1 | Default Install Location | `defaultInstallLocation` | path | `/Applications` |
| 2 | Download File Location | `downloadLocation` | path | `~/Downloads` |
| 3 | Applications to show | `enabledAppIds` | set of registry `id` | all with `enabledByDefault` |
| 4 | Automatically Download Updates | `autoDownload` | bool | off |
| 5 | Automatically Install Updates | `autoInstall` | bool | off |
| 6 | Launch at login | `launchAtLogin` | bool | off |

## Requirements
- **REQ-SET-1** Items 1 and 2 show the current path and a **Choose…** button opening a folder picker.
- **REQ-SET-2** A chosen folder MUST exist and be writable; otherwise the choice is rejected with `permissionDenied` and the previous value kept. If a stored folder later disappears (e.g. unmounted drive), the setting is kept but flagged invalid and the relevant operations fail with `permissionDenied`/`folderMissing`.
- **REQ-SET-3** Item 3 lists every Registry App with icon, name and a checkbox; the list reflects registry changes. New Apps appearing in the registry are enabled iff `enabledByDefault`. Unchecking an installed App only hides it; it is not uninstalled.
- **REQ-SET-4** Turning **Automatically Install** on forces **Automatically Download** on and locks it on; turning Install off unlocks Download, which keeps its value.
- **REQ-SET-5** Behaviour of the toggles is the matrix in [06](06-notifications.md).
- **REQ-SET-6** **Launch at login** registers/unregisters with `SMAppService.mainApp`. If registration fails (or needs approval in System Settings), the toggle reverts and the status line explains.
- **REQ-SET-7** Changes take effect immediately; there is no Save button.
- **REQ-SET-8** Settings access goes through the `SettingsStoring` protocol ([08](08-architecture.md)).

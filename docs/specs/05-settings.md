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
| 7 | GitHub token (optional) | Keychain item, not `UserDefaults` | secret string | none |
| 8 | App order | `appOrder` | list of registry `id` | none (= registry order) |

## Requirements
- **REQ-SET-1** Items 1 and 2 show the current path and a **Choose…** button opening a folder picker.
- **REQ-SET-2** A chosen folder MUST exist and be writable; otherwise the choice is rejected with `permissionDenied` and the previous value kept. If a stored folder later disappears (e.g. unmounted drive), the setting is kept but flagged invalid and the relevant operations fail with `permissionDenied`/`folderMissing`.
- **REQ-SET-3** Item 3 lists every Registry App with icon (REQ-WIN-25 precedence), name and a checkbox; the list reflects registry changes. New Apps appearing in the registry are enabled iff `enabledByDefault`. Unchecking an installed App only hides it; it is not uninstalled.
- **REQ-SET-4** Turning **Automatically Install** on forces **Automatically Download** on and locks it on; turning Install off unlocks Download, which keeps its value.
- **REQ-SET-5** Behaviour of the toggles is the matrix in [06](06-notifications.md).
- **REQ-SET-6** **Launch at login** registers/unregisters with `SMAppService.mainApp`. If registration fails (or needs approval in System Settings), the toggle reverts and the status line explains.
- **REQ-SET-7** Changes take effect immediately; there is no Save button.
- **REQ-SET-9** An optional **GitHub token** field is an advanced setting: the GitHub section appears only if the Option key is held when Settings is activated (e.g. Option-click the toolbar Settings button or the app menu's Settings item), stays visible until that Settings window closes, and is otherwise hidden. It is a secure text field (`settings.githubToken`) that stores the token in the Keychain, never in `UserDefaults` or the state file. It raises the API rate limit and lets the registry refresh read a private repository (REQ-REG-11). Clearing the field removes the Keychain item. The token is never shown in the status line or logs.
- **REQ-SET-10** The *App order* chosen in the Settings list is the order of rows in the main window and of lines in the menu bar menu. Apps missing from the saved order (e.g. newly added to the registry) go at the end in registry order; ids in the saved order that left the registry are ignored; installed Apps that left the registry still come after all others (REQ-REG-4). The Settings list shows every App, checked or not; an unchecked App keeps its place, and the main window shows only the checked ones in the App order. If the order equals the registry order it is stored as unset.
- **REQ-SET-13** The Apps list in Settings is tall enough to show every App at once, without an inner scroll area, so all Apps can be selected and moved.
- **REQ-SET-11** Rows in the Settings Apps list are reordered by dragging. Each row also has a right-click (context) menu with "Move Up" and "Move Down", and exposes the same as accessibility actions; there are no on-screen arrow buttons.
- **REQ-SET-12** A **Reset Order** button (`settings.apps.resetOrder`) under the list clears the App order back to the registry order; it is disabled while the order is already the default.
- **REQ-SET-8** Settings access goes through the `SettingsStoring` protocol ([08](08-architecture.md)).

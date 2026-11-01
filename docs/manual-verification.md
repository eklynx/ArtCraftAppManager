# Manual verification

Checks that cannot run hermetically (real volumes, system prompts, Gatekeeper, login items). Run them after a build with the automated suite green. Report back which step failed and what the status line said.

Setup once: build and run the Manager from Xcode (or open the built `.app`). Have a second volume available as an install target.

| # | Area | Steps | Expected | Specs |
|---|---|---|---|---|
| 1 | Install to another volume | In Settings choose a folder on the second volume as Default Install Location. In the main window click Install on an App. Accept the prefilled folder. | Progress bar with percentage and Cancel; then the row shows `Ver:` and the chosen folder. The `.app` exists there. Download Location has no leftover `.dmg`. | INS-5, INS-12, WIN-14 |
| 2 | Detection | Quit the Manager, move the installed `.app` to another folder on the same volume, relaunch. | The row still shows the App, now at the new path. | INS-1, INS-3 |
| 3 | Update | Install an older release by hand (or edit the App's version in its `Info.plist`), then click Refresh. | Row shows `Ver: old → new` and an enabled Update button. Update replaces the App in the same folder; the old copy is in the Trash. | WIN-13, INS-9, INS-10 |
| 4 | Running app | With an update available, launch the App and try Update. | Update is greyed with a tooltip; clicking is blocked with "Quit <App> to update". The App is never quit. | INS-11, WIN-15 |
| 5 | Auto install | Turn on Automatically Install Updates (Automatically Download turns on and locks). With the App running, trigger a check. | One "ready, but running" notification; after quitting the App it is updated and an "updated" notification appears. | NOT-4, NOT-5, SET-4 |
| 6 | Notifications | Deny notification permission in System Settings, trigger an update check. | No banners; the menu bar badge (if Launch at login is on) shows the count. Clicking a banner (when allowed) activates the Manager at that row. | NOT-1, NOT-2 |
| 7 | Launch at login | Turn on Launch at login (approve in System Settings if asked), log out and in. | The Manager starts with no window and a menu bar icon; closing the window afterwards keeps it running. With the setting off, closing the window quits. | SET-6, WIN-9, WIN-10, WIN-11 |
| 8 | Gatekeeper | Open an installed App for the first time. | It opens as a normally downloaded app would (quarantine was not stripped). | INS-8 |
| 9 | Uninstall | Click Uninstall and confirm. | The App moves to the Trash; its data and preferences remain. | INS-14 |
| 10 | Remote registry | Make sure the repository is public (or store a GitHub token: Option-click Settings to reveal the hidden GitHub field), add an App entry to `docs/registry/apps.json` on `main`, relaunch. | The new App appears without a new Manager build. | REG-2, REG-3 |

| 11 | App order | Open Settings, drag a row in the Apps list to a new position (use the handle at the right of the row). | The row moves; Reset Order becomes enabled; the main window lists the checked apps in the new order; Reset Order restores the original order. (Right-click → Move Up/Move Down should also work.) | SET-10, SET-11, SET-12 |
| 12 | Row context menu | Right-click an installed App's row. | A menu shows two greyed lines ("Updated by Manager", "Released"/"File date") then Run, Update, Open Location, Uninstall, Cancel, Copy Install Path, Open Releases Page; unavailable entries are greyed and enabled ones match the row's buttons. Copy Install Path puts the path on the clipboard; Open Releases Page opens GitHub. | WIN-22, WIN-23, WIN-24 |
| 13 | Downloaded icons | Uninstall (or pick) an App that is not installed and relaunch the Manager online; then go offline and relaunch. | The row and the Settings list show the App's real icon instead of the dashed placeholder; the icon still shows offline from the cache. | WIN-25 |

Known limitation: login-launch detection uses the login-item Apple event and is best-effort; if the window appears at login, report it.

# 04 — Main Window (`WIN`)

Prototype: [`../prototypes/ApplicationLine.svg`](../prototypes/ApplicationLine.svg) (900×100 row).

## List
- **REQ-WIN-1** The window lists the Apps that are enabled in Settings, in the user's App order (registry order by default, REQ-SET-10), plus installed Apps that left the registry (REQ-REG-4).
- **REQ-WIN-2** Each row shows: App icon (installed app's icon, else `iconUrl`, else fallback glyph), name, `Ver: x.y.z` (installed version), and the install path. Not-installed rows show "Not installed" in place of version and path.
- **REQ-WIN-3** Installed rows have buttons: **Run**, **Open Location**, **Uninstall** and **Update**. The Update button is **hidden** when no update is available (REQ-REG-8), leaving its slot empty. When an update is available it is shown, enabled unless the App is running (REQ-WIN-15). *Provisional:* the user may prefer an always-visible, greyed-out Update button after trying the app (see [implementation notes](../implementation-notes.md)); keep this behaviour in one view-model flag (`hidesUpdateWhenCurrent`) so the change is a one-line switch.
- **REQ-WIN-21** All buttons on a row (Install, Uninstall, Update, Run, Open Location) have the same fixed width regardless of their title, as in the prototype.
- **REQ-WIN-4** Not-installed rows keep the same size and layout. The path line reads "Not installed", and a single **Install** button sits in the Uninstall slot (top of the left button column); the other slots are empty.
- **REQ-WIN-5** A **Refresh** control triggers REQ-REG-12; a spinner shows while checking.
- **REQ-WIN-6** Empty state: if no Apps are enabled, show "No applications selected" with a button opening Settings.

## Status line
- **REQ-WIN-7** The bottom of the window has a single status line showing the most recent error or important status (text in [07](07-errors-and-status.md)). It is cleared on the next successful operation, or on click.
- **REQ-WIN-8** While offline, previously known data is shown and the status line says so.

## Menu bar item
- **REQ-WIN-9** When "Launch at login" is on, a menu bar icon exists with: update badge (count), "Open Manager", "Check Now", "Quit". With the setting off there is no menu bar icon.
- **REQ-WIN-10** Closing the window quits the app unless "Launch at login" is on, in which case the app keeps running in the menu bar.
- **REQ-WIN-11** When started by the login item, the app MUST NOT show its window.

## Row states (decided after reviewing the prototype)
- **REQ-WIN-13** Update available: the version line reads `Ver: 1.2.34 → 1.3.0` (installed → available).
- **REQ-WIN-14** Busy (downloading/installing): the button area is replaced by a progress bar with a percentage, plus **Cancel** during the download phase only. Version and path text are unchanged. Buttons return when the operation ends.
- **REQ-WIN-15** Running: a small "Running" label appears beside the version. Update and Uninstall are disabled (greyed, in the prototype's button style) with a tooltip such as "Quit GridCraft to update". **Run** stays enabled and brings the App to the front.
- **REQ-WIN-16** No longer in registry: the row looks like a normal installed row, with "No longer in registry" in place of the update arrow, and no Update button (REQ-REG-4).

## Window layout
- **REQ-WIN-17** The window is a single column of rows (prototype width 900) in a scroll view.
- **REQ-WIN-18** A standard macOS toolbar above the list has **Refresh** (REQ-WIN-5) and **Settings**. The status line (REQ-WIN-7) is a thin plain-text bar pinned to the bottom.

## Menu bar menu
- **REQ-WIN-19** The menu bar icon (REQ-WIN-9) is a template glyph with a count badge when updates are available. The menu lists one line per App with an update, in the App order, (e.g. "GridCraft 0.14.2 → 0.15.0"), then **Check Now**, **Open Manager**, **Quit**.
- **REQ-WIN-20** Clicking an App line opens the Manager scrolled to that App's row.
- **REQ-WIN-22** Right-clicking (or Control-clicking) a row opens a context menu. Its entries, in this fixed order, are: **Install** (not installed) or **Run**; **Update**; **Open Location**; **Uninstall**; **Cancel** (only enabled during the download phase); **Copy Install Path**; **Open Releases Page** (the registry `releasesUrl`). Entries that do not apply are disabled, not hidden. "No longer in registry" rows show only Run, Open Location, Uninstall and Copy Install Path. Uninstall asks for the same confirmation as the button (REQ-INS-14). The entries are also exposed as accessibility actions.
- **REQ-WIN-23** The menu starts with two greyed, non-clickable information lines, then a divider. **Updated by Manager: <date>** is when the Manager last installed or updated the installed version; for a copy it never installed this version of, it reads "Not installed by Manager". **Released: <date>** is the GitHub publish date of the installed version; when unknown it reads "File date: <date>" using the `.app`'s modification date. A not-installed row shows the single line "Not installed". Dates are formatted `d MMM yyyy`.
- **REQ-WIN-24** The menu and the row buttons never disagree: an action is enabled in the menu exactly when its button is enabled (running, busy and update-available rules of REQ-WIN-3/14/15 apply to both).

## Accessibility
- **REQ-WIN-12** All buttons have accessibility labels including the App name (e.g. "Update GridCraft"); rows are navigable by keyboard.

# 04 — Main Window (`WIN`)

Prototype: [`../prototypes/ApplicationLine.svg`](../prototypes/ApplicationLine.svg) (900×100 row).

## List
- **REQ-WIN-1** The window lists the Apps that are enabled in Settings, in registry order, plus installed Apps that left the registry (REQ-REG-4).
- **REQ-WIN-2** Each row shows: App icon (installed app's icon, else `iconUrl`, else fallback glyph), name, `Ver: x.y.z` (installed version), and the install path. Not-installed rows show "Not installed" in place of version and path.
- **REQ-WIN-3** Installed rows have buttons: **Run**, **Open Location**, **Uninstall**, **Update**. Update is enabled only when an update is available (REQ-REG-8) and the App is not running; if an update is available, the row also shows the available version.
- **REQ-WIN-4** Not-installed rows show a single **Install** button.
- **REQ-WIN-5** A **Refresh** control triggers REQ-REG-12; a spinner shows while checking.
- **REQ-WIN-6** Empty state: if no Apps are enabled, show "No applications selected" with a button opening Settings.

## Status line
- **REQ-WIN-7** The bottom of the window has a single status line showing the most recent error or important status (text in [07](07-errors-and-status.md)). It is cleared on the next successful operation, or on click.
- **REQ-WIN-8** While offline, previously known data is shown and the status line says so.

## Menu bar item
- **REQ-WIN-9** When "Launch at login" is on, a menu bar icon exists with: update badge (count), "Open Manager", "Check Now", "Quit". With the setting off there is no menu bar icon.
- **REQ-WIN-10** Closing the window quits the app unless "Launch at login" is on, in which case the app keeps running in the menu bar.
- **REQ-WIN-11** When started by the login item, the app MUST NOT show its window.

## Accessibility
- **REQ-WIN-12** All buttons have accessibility labels including the App name (e.g. "Update GridCraft"); rows are navigable by keyboard.

# Implementation notes

Running log of decisions, changes and tradeoffs beyond the README. Dated 2026-10-31.

## Decisions not in the README
- **App list** = 14 apps from GitHub org `storytold`, each with a macOS universal `.dmg` in its latest release: artcraft, vectorcraft, photocraft, figcraft, soundcraft, cadcraft, gridcraft, deckcraft, wordcraft, effectcraft, pdfcraft, designcraft, filmcraft, lightcraft. Excluded: `craft-launcher` (the vendor's own manager), `craft-anything` (v0.1.0, experimental), AniCraft/crafthub (no releases).
- **Release naming differs for ArtCraft**: tag `artcraft-vX.Y.Z`, asset `ArtCraft_X.Y.Z_universal.dmg`, no `SHA256SUMS.txt`. The other 13 use `vX.Y.Z` / `<id>-X.Y.Z-macos-universal.dmg` / `SHA256SUMS.txt`. Handled via per-app regex patterns in the registry; all 14 patterns were checked against the live latest releases (each matched exactly one dmg).
- **Registry**: bundled + remote refresh from this repo's `main` raw URL (ADR 0002). Lives at `docs/registry/apps.json`, with a JSON Schema; the app bundle references that file directly (REQ-ARC-7).
- **Sandbox off** (ADR 0001) — the template had it on.
- **Added a "Launch at login" setting** (not in README) with a menu bar item, at the user's request.
- **Auto Install forces Auto Download on** (README implied it, now explicit).
- **Update checks** at launch + every 6h + manual refresh; ETag conditional requests to stay inside the 60/h unauthenticated GitHub limit (14 apps ⇒ 14 requests per full check).
- Pre-releases ignored; never force-quit a running app; install-on-quit for running apps; safe replace with Trash of old copy; uninstall leaves user data.
- Tests: Swift Testing for unit, XCUITest for smoke; `SpecCoverageTests` enforces that every REQ ID has a test.

## UI decisions (from reviewing `docs/prototypes/ApplicationLine.svg`)
- The prototype shows one installed row only; the Install, update-available, busy, running, removed-from-registry rows, toolbar, status line and menu bar menu were designed in a grilling round and recorded as REQ-WIN-3/4 and 13–20.
- **Update button is hidden when there is no update** (REQ-WIN-3). This is explicitly **provisional**: the user wants to try it and may switch to an always-visible greyed-out button. Implement behind a single view-model flag.
- Install button takes the Uninstall slot so rows keep one shape.

## Bundle IDs (from GitHub source)
- 13 Craft apps: `packaging/macos/Info.plist.in` → `ai.storyteller.<id>` (e.g. `ai.storyteller.photocraft`).
- ArtCraft is a Tauri app with no `Info.plist.in`; its ID is `identifier` in `crates/desktop/artcraft/tauri.conf.json` → `ai.artcraft.app`.
- The plist `CFBundleName` showed CADCraft is spelled `CADCraft`, so I corrected `displayName` and `appBundleName` from the earlier `CadCraft`.

## Open / unverified
- `appBundleName` and `bundleId` come from the templated source (`Info.plist.in` / Tauri config), not a mounted DMG. Decision (user): trust the source for now. If install ever reports `bundleMissing` or detection misses an app, check against a real DMG first.
- `iconUrl` is `null`; icons come from the installed app until a source is chosen.
- No JSON-Schema validation was run (no `jsonschema` available offline); only `jq` syntax checks and pattern-vs-release checks. Schema validation is covered by REQ-TST-4 once the test target exists.

## Tests (written red-first)
- 104 Swift Testing cases in `ArtCraftAppManagerTests` plus 9 XCUITest smoke tests in `ArtCraftAppManagerUITests`; every one of the 84 `REQ-*` ids is referenced (enforced by `SpecCoverageTests`).
- To make this possible I added **contract code** to the app target (protocols, models, `ManagerError`, and stubs). Behaviour stubs return harmless defaults so failures are assertions, not crashes. Implemented for real because they are data/catalogue: `ManagerError`, registry models, `ChecksumList`, `UserDefaultsSettingsStore`.
- Contract stubs were then implemented; the last unit run is **104 of 104 passing** (including real `hdiutil` mount/unmount, quarantine preservation and read-only-folder cases). The XCUITests compile but have not been run: they need the real UI and its accessibility identifiers.
- Decisions made while implementing: (1) `InstallationManaging` gained `download(_:app:progress:)` so Auto Download can fetch and verify without installing. (2) An update swaps by renaming the old copy to `<Name>.previous-<id>.app`, moving the verified new copy in, then trashing the backup; if the trash step fails the swap is rolled back (so a failed Trash leaves the old version in place). (3) Downloads reuse an existing disk image only when a checksum is published and matches. (4) Tests compare URL *paths*, because `URL ==` differs by trailing slash once a directory exists. (5) `AppVersion` equality pads with zeros, so `1.0` == `1.0.0`.
- **Project changes needed by the tests**: App Sandbox set to NO (ADR 0001; tests read the repo via `#filePath`), `SWIFT_DEFAULT_ACTOR_ISOLATION` changed from `MainActor` to `nonisolated` for the app target (model/logic code must not be main-actor-bound by default; views are still main-actor via SwiftUI), and `docs/registry/apps.json` added to the app target's Copy Bundle Resources from `SOURCE_ROOT` (REQ-REG-1, REQ-ARC-7).
- The Xcode template already used Swift Testing, so no XCTest→Swift Testing switch was needed (earlier note was wrong).
- Some specs are checked indirectly: `REQ-NOT-7` (no background agent) is a pbxproj grep plus the 6-hour interval; `REQ-ARC-1/2/3/5/7` are source/project scans.

## Findings from a live run
- A real launch fetched release data for all 14 apps from GitHub (14 ETags stored), so the fetcher/resolver work against the live API.
- **Resolved 2026-11-01: the repo is now public.** It was private during the first live run, so the remote registry URL (`raw.githubusercontent.com/.../main/docs/registry/apps.json`) returned 404 and the app silently used the bundled registry (by design, REQ-REG-3). After the change the URL returns 200 and the remote file is byte-identical to the bundled one (schema 1, 14 apps, with icon URLs), so remote refresh now works. The GitHub token field (REQ-SET-9) is no longer needed for the registry; it still raises the API rate limit for release lookups.
- Test launches (hosted unit tests and `-uitest-*` UI launches) now use an isolated defaults suite and a temp state folder and skip the network, after the first test runs wrote a fake GridCraft entry and notification records into the real `state.json` (deleted; the file is disposable).
- UI tests drive the real app: keep the mouse and keyboard off while they run.

## GitHub token setting
- Added REQ-SET-9 (not in the README): an optional GitHub token in Settings, stored in the Keychain via `KeychainTokenProvider`. Used for release lookups and for the registry refresh, so a private repo works. Test launches never read or write the real Keychain item. The Keychain access itself is only checked manually (there is no hermetic test for it).
- The GitHub section is hidden unless Option is held when Settings is activated, and stays until that Settings window closes. Note the keyboard shortcut cannot carry the Option key (`⌘⌥,` is a different shortcut from the menu's `⌘,`), so reveal it by Option-clicking the toolbar Settings button or the app menu's Settings item. Detection reads `NSEvent.modifierFlags` when the Settings window becomes key.
- Suite is **119 of 119** (110 unit + 10 UI) with this change.

## App order (reordering the Settings list)
- Decisions (grilled with the user): one order drives the main window rows and the menu bar menu; stored as `appOrder` (list of ids, unset = registry order); apps missing from it are appended, unknown ids ignored; unchecked apps keep their place; a Reset Order button restores the default. Logic is `AppOrder` in `Settings/AppOrder.swift`; glossary term "App order" added. Specs: REQ-SET-10/11/12 (+ REQ-WIN-1 wording).
- **Drag-and-drop reordering is implemented (`onMove` with a visible handle) but not verified by an automated test**: XCUITest's synthetic drag never triggered the list's move, and I could not tell whether that is the test tool or the app. To guarantee a tested path I added a right-click menu with Move Up / Move Down (also exposed as accessibility actions). This goes slightly beyond the "no on-screen arrows" decision but adds no visible controls. Please try dragging a row by hand (see `docs/manual-verification.md`); if it does not work, tell me and I will fix or drop it.
- Suite: **131 of 131** with this change.

## UI fixes after first hands-on use
- Row buttons: the label now fills a fixed-width button (140 pt), so every button is the same width whatever its title (REQ-WIN-21; matches the prototype).
- Settings app list: the list was only 180 pt tall (inner scroll) and the Settings window opened 450 pt tall, hiding apps. The list now sizes to show every app and the window opens ~860 pt tall (resizable, scrolls on small screens) (REQ-SET-13). A UI test checks the last of 14 apps is hittable.
- Suite: **132 of 132**.

## Row context menu (REQ-WIN-22…24)
- Right-click a row: two greyed info lines, then Install/Run, Update, Open Location, Uninstall, Cancel, Copy Install Path, Open Releases Page. Disabled rather than hidden, except rows removed from the registry (four entries).
- "Updated by Manager" and "Released" are stored per app **and version** in the state file (`installDates`, `publishDates`, key `appId|version`), so a hand-update never shows a stale date; the first line then reads "Not installed by Manager". `Release` gained `publishedAt` (GitHub `published_at`). `DiskInstaller.onInstalled` records installs/updates, including auto-updates. Publish dates are recorded on every release fetch, so they fill in after the first refresh. Fallbacks: "File date: …" then "Released: unknown".
- `ManagerState` now decodes tolerantly, so older state files keep loading.
- Menu enabled-state is derived from `enabledButtons`, so menu and buttons cannot disagree (tested).
- The row needed `contentShape` for right-click to hit the spacer area; menu items must not carry an accessibility label that differs from their title (UI tests find them by title).
- **Known failing UI test**: `test_REQ_WIN_9_REQ_WIN_11_loginLaunchHasNoWindowButAMenuBarItem` now fails (the main window appears on a login-style launch). It fails identically with this change stashed, so it is not caused by it; it passed in the previous run. Not yet diagnosed.
- Suite: 13 of 14 UI tests and all unit tests pass.

## Icons from GitHub (REQ-WIN-25, REQ-REG-13)
- `iconUrl` is now set for all 14 apps (raw.githubusercontent.com PNG; Craft apps: `assets/app-icon/hicolor/256x256/apps/ai.storyteller.<id>.png`, ArtCraft: `crates/desktop/artcraft/icons/128x128@2x.png`). All 14 were checked live: HTTP 200, image/png.
- New `Icons/` namespace: `AppIconProviding`, `GitHubIconProvider` (disk cache in `~/Library/Caches/ArtCraftAppManager/icons`, ETag revalidation after 24 h, 2 MB cap, must decode as an image, stale copy kept on failure), `IconChoice` (installed → cached → placeholder). `AppModel.loadIcons()` runs after each refresh; test launches skip it.
- **Deviation from the plan**: no GitHub token is sent for icon downloads. The repos are public, and a stale or wrong token would turn a public 200 into a 401.
- The Settings list now shows icons (REQ-SET-3 already said so; it was missing). Rows grew, so the list height is 34 pt per row.
- **Settings window size**: the `idealHeight` frame was not what sized the window (it opened 608 pt tall after the icons were added, clipping the last app). The Settings scene now uses `.defaultSize(width: 520, height: 940)`. This also explains the earlier "860 pt" fix being fragile.
- The login-launch UI test that failed in the previous step passed in the latest runs, so it looks flaky rather than broken. Not diagnosed.

## App icon and menu bar icon
- Source is `docs/prototypes/AppIcon.svg`; `scripts/export-icons.sh` regenerates the committed PNGs (`AppIcon.appiconset` 16–1024 px, `MenuBarIcon.imageset` 18/36 px). REQ-WIN-26 is new; REQ-WIN-19 changed from "template glyph" to full colour (user's choice: full colour, keep the rounded box with transparent corners).
- **Renderer**: `qlmanage` paints an opaque background, so `scripts/render-svg.swift` renders through `NSImage` (CoreSVG) into a transparent bitmap. CoreSVG ignores SVG filters, so the tile drop shadows are lost and the app icon's body shadow is redrawn with `NSShadow`. The menu bar variant is the same SVG cropped to the rounded box (no shadow).
- The menu bar label is `Image("MenuBarIcon").renderingMode(.original)`; the update count text still follows it.
- Small sizes: the four-tile layout is still readable at 18/36 px but the glyphs inside the tiles blur at 16 px; no design change made.
- The asset files were generated before `AppIconAssetTests` was written, so that test was never red.

## Contract vs implementation files
- New rule (user request, REQ-ARC-9): a file that declares a protocol holds only protocols and plain data types; implementations and logic-bearing types (classes, actors, resolvers, planners, validators, schedulers) live in their own files named after the type, in the same namespace folder.
- Move-only refactor, no behaviour change: `Install.swift`, `Releases.swift`, `Notifications.swift`, `Settings.swift`, `State/ManagerState.swift`, `Detection.swift`, `Icons.swift` and `AppRegistry.swift` shrank to contracts; `WorkspaceAdapters.swift` and `NotificationAdapters.swift` were split per type and deleted; `RegistryProvider.swift` was renamed `BundledRemoteRegistryProvider.swift`. Each contract header now lists its implementation files.
- Plain-data types that appear in protocol signatures (`InstalledApp`, `Release`, `AppVersion`, `ManagerState`, `RegistryApp` …) stay in the contract file. Enums that only hold `static func` logic (`IconChoice`, `AppOrder`, `UpdatePlanner` …) count as logic and moved.
- The files were split with a script, so each moved file kept the original file's `import` lines; some imports are now unused (harmless).
- `ArchitectureTests` gained `REQ-ARC-9`; it was red before the moves.

## Manual verification result
- 2026-11-01: the user ran the full manual checklist (`docs/manual-verification.md`, steps 1–13) and reported that all steps succeeded. That covers the real install/update onto another drive, Gatekeeper, notifications, login item, drag reordering, the row context menu and downloaded icons.

## Not done
- Production adapters written: `URLSessionTransport`, `KeychainTokenProvider`, `BundledRemoteRegistryProvider` (unit-tested through fakes), `URLSessionDownloader`, `FileManagerTrasher`, `WorkspaceLauncher`, `SystemAppLookup` (LaunchServices + `mdfind`), `UserNotificationNotifier`, `WorkspaceQuitObserver`, `SMAppServiceLoginItem`. The system-facing ones are not unit-tested (REQ-TST-3 keeps tests off the real network/Trash/login items); they need the manual checks below.
- UI built (step 2): `App/AppModel.swift` is the composition root (the only place concrete adapters are named; `ArchitectureTests` bans them from `UI/`). `UI/MainView.swift` (rows follow `ApplicationLine.svg`: two button columns, fixed slots so rows stay aligned), `UI/SettingsView.swift` (+ menu bar content), `ArtCraftAppManagerApp.swift` (`Window` + `Settings` + `MenuBarExtra`, quit-on-last-window per `AppLifecyclePolicy`).
- **Full suite: 116 of 116 pass** (108 unit + 9 XCUITest against the real UI). UI tests use launch arguments handled by `AppModel` (`-uitest-no-enabled-apps`, `-uitest-offline`, `-uitest-installed-<id>`, `-uitest-started-by-login-item`); `-uitest-offline` skips the network so the status text stays put.
- macOS exposes static-text strings as `value` (not `label`) to XCUITest, and settings `Toggle`s as `switches`; the UI tests account for both.
- **Manual checks (all since passed, see "Manual verification result")** (cannot be automated hermetically): a real install/update of one app onto an external volume; Gatekeeper first launch; notification permission prompt and click-through; real login-item approval and the login-launch detection (`NSAppleEventManager` `keyAELaunchedAsLogInItem` is best-effort); Spotlight/LaunchServices detection of an app on an external volume.
- `README.md` was left untouched (typos and all); it is currently staged as a rename in git.

## GitHub Actions (build, test, sign/package)
- Workflows: `unit-tests.yml`, `ui-tests.yml`, `release.yml`; scripts `compute-version.sh`, `package-dmg.sh`, `ExportOptions.plist`; guide in `docs/ci.md`; requirements REQ-TST-6/7 with `WorkflowTests`.
- Not run for real: signing, notarization and the release job need your Apple secrets, . The default runner label `xcode-27` was given by the user (not checked against GitHub); the jobs are untested until the first run. `actionlint` and `shellcheck` are not installed here, so I only checked that the YAML parses and that the unit suite (including the new workflow tests) passes locally.
- There is no separate `ci.yml`: `xcodebuild test` already proves the build compiles.
- Release is manual (`workflow_dispatch` with a `bump` input) rather than tag-triggered, because versions auto-increment; the workflow creates the tag via `gh release create --target $GITHUB_SHA`.
- `MARKETING_VERSION` is always plain `X.Y.Z` (a `-timestamp.hash` suffix is invalid in `CFBundleShortVersionString`); the full dev version only names the unsigned artifact from `main` pushes.
- Unit Tests on `main` pushes also upload an unsigned app zip; PRs never build it, and only Release references secrets (checked by `WorkflowTests`).
- Run UI Tests falls back to `["self-hosted","macOS"]` when neither the input nor `RUNNER_LABELS` is set, so it never lands on a hosted runner by accident.
- Signing uses command-line overrides (manual, Developer ID Application, team `NMX3RG6P6L` hard-coded, also in `ExportOptions.plist`); the project file keeps automatic signing for local builds. The DMG is signed, notarized and stapled; the app inside is signed and hardened by the archive/export step.
- `XCODE_VERSION` selects `/Applications/Xcode_<version>.app`, which is the hosted-runner layout; a self-hosted Mac should leave it unset and use `xcode-select`.
- The README line about `README.md` being "staged as a rename" above is stale history; I only added a CI sentence to it.

### Nightly build
- `nightly.yml` (03:00 UTC + manual) builds a fully signed, notarized, stapled DMG with the dev version and publishes it as a GitHub **pre-release** (`--prerelease --latest=false`) tagged `nightly-<version>`. The signing steps moved out of `release.yml` into the reusable `package.yml`; Release now has `unit-tests`, `package`, `publish` jobs.
- The first version of this was a workflow artifact with 7-day retention; the user corrected it to a pre-release. Retention is now a prune step in the same workflow (see the change below); the artifact between jobs lives 1 day.
- `compute-version.sh dev` now also prints `tag=nightly-<version>`. These tags don't match the `vX.Y.Z` filter, so they never affect release numbering.
- Superseded: scheduled runs first skipped nights with no commit in the last 25 hours.
- Added the glossary term **Nightly build** so it isn't confused with a Manager release.
- Scheduled workflows only run from the default branch, and GitHub disables schedules after 60 days without repo activity.
- Change (user): a nightly is skipped when `main` is unchanged, judged by comparing the latest `nightly-*` release's `targetCommitish` with the current commit, rather than by commit age. A failed earlier attempt leaves no release, so the next run retries. This applies to manual runs too; they have a `force` input to build anyway (my addition).
- Change (user): retention is the last 7 nightlies by count, not 7 days, so skipped nights don't shrink the history. The prune step deletes older `nightly-*` releases with `--cleanup-tag`.

### CodeQL
- Default setup's Swift job failed (CodeQL tracer segfault, exit 139) and default setup was then narrowed to `actions`. I turned default setup off and added `codeql.yml`.
- Tried and ruled out for Swift on hosted runners: autobuild (segfault), `build-mode: none` (unsupported for Swift), manual `xcodebuild` on the `xcode-27` runner (tracer breaks the macro plugin server: "Bad CPU type in executable"). Swift is therefore opt-in via the `CODEQL_SWIFT` variable; only `actions` is scanned by default. **Swift code is currently not scanned by CodeQL.**
- Unrelated, seen while doing this: `DiskImageIntegrationTests/realDmg` (real `hdiutil`) fails intermittently on the hosted runner (failed on the `main` push after PR #2 and on this PR; passed on other runs). Not investigated.


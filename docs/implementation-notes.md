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

## Not done
- Production adapters are not written: the real `HTTPTransport` (URLSession), `Downloading`, `Trashing` (NSWorkspace/FileManager.trashItem), `AppLaunching`, `QuitObserving` (NSWorkspace), `UpdateNotifying` (UNUserNotificationCenter), `LoginItemControlling` (SMAppService), Keychain `TokenProviding`, `AppRegistryProviding`, and the SwiftUI views (still the template `ContentView`). The logic behind each protocol is implemented and tested against fakes.
- `README.md` was left untouched (typos and all); it is currently staged as a rename in git.

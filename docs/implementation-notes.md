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

## Not done
- No Swift code and no test code yet — this pass is specifications, registry and ADRs only. The test target switch to Swift Testing and `SpecCoverageTests` are described in `specs/09-test-plan.md` but not written; the "tests cover specs" rule is therefore pending until implementation.
- `README.md` was left untouched (typos and all); it is currently staged as a rename in git.

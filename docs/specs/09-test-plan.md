# 09 — Test Plan (`TST`)

## Strategy
- **REQ-TST-1** Every `REQ-*` ID in `docs/specs/*.md` MUST be referenced (test name or comment) by at least one test. A test (`SpecCoverageTests`) scans the specs and the test sources and fails on any uncovered ID. IDs marked `(withdrawn)` are exempt.
- **REQ-TST-2** Unit tests use Swift Testing (`import Testing`) in `ArtCraftAppManagerTests` (the Xcode template already uses it; its sample test was removed). UI smoke tests use XCUITest in `ArtCraftAppManagerUITests`.
- **REQ-TST-3** Tests are hermetic: protocol fakes ([08](08-architecture.md)), temporary folders under `$TMPDIR`, no network, no real Trash.
- **REQ-TST-4** Registry tests: `apps.json` validates against `apps.schema.json`; ids unique; every `tagPattern`/`assetPattern` compiles and contains a `version` group; each pattern matches the fixture release JSON of its App (fixtures captured from the 14 real latest releases on 2026-10-31).
- **REQ-TST-5** Install tests use a tiny fixture DMG containing a stub `.app` (created by a script at test setup with `hdiutil`); safe-replace tests inject failures at each step and assert the old App is intact.

## Conventions
- Swift Testing tests carry requirement IDs in their display name (`@Test("REQ-REG-8 …")`). XCUITest method names cannot contain hyphens, so they use `test_REQ_WIN_1_…`; `SpecCoverageTests` treats `REQ_X_n` as `REQ-X-n`.
- Contract code (protocols, models, `ManagerError`) lives in the app target by area folder (`Registry/`, `Releases/`, `Detection/`, `Install/`, `Settings/`, `Notifications/`, `State/`, `UI/`). Behaviour not yet implemented is a stub marked `// Red: not implemented yet.` so tests fail by assertion, never by crash.
- Shared fakes: `ArtCraftAppManagerTests/Support/Fakes.swift`; helpers and fixture paths: `Support/TestSupport.swift`. Tests locate the repo through `#filePath`, so the app and tests run unsandboxed (ADR 0001).
- UI accessibility identifiers used by XCUITests are listed at the top of `MainWindowUITests.swift` and are part of the UI contract.

## Fixtures
- `ArtCraftAppManagerTests/Fixtures/releases/<id>.json` – the 14 real `releases/latest` payloads captured 2026-10-31 (tag, draft, prerelease, asset names/URLs). Draft, prerelease, no-macOS-asset and 304 cases are built in code (`releaseJSON(...)`, `FakeHTTPTransport`).
- A stub DMG is generated with `hdiutil` at test time (`DiskImageIntegrationTests`); other install tests use `FakeMounter` and temp folders. Checksum lists are built in code.

## Traceability matrix
Test names follow `REQ-<AREA>-<n>_<behaviour>`. Level: **U** unit, **I** integration (real filesystem/hdiutil, no network), **UI** XCUITest.

| Area | Requirements | Level |
|---|---|---|
| OVR | OVR-1…4 | covered by the INS/REG/WIN tests that realise them (U/UI) |
| REG | REG-1…13 | U (REG-1 bundle resource, REG-2/3 fallback chain, REG-6/7 release filtering, REG-8 version compare, REG-9/10 ETag/rate limit, REG-12 scheduler) |
| INS | INS-1…4 | U with fake locator |
| INS | INS-5…8, 10, 12, 13 | I (temp dirs + fixture DMG) |
| INS | INS-9, 11, 14…17 | U with fakes (running state, trash, concurrency, cancel) |
| WIN | WIN-1…8, 12…18, 21…26 | UI smoke + U view-model (row-state table per REQ-WIN-3/4/13…16) |
| WIN | WIN-26 | U (asset files: slots, pixel sizes, transparent corners) + manual look |
| WIN | WIN-9…11, 19, 20 | U (login-item state, menu model) + manual check |
| SET | SET-1…13 | U (store, validation, toggle coupling); UI for pickers |
| NOT | NOT-1…8 | U (matrix table-driven, dedupe, quit-observation via fake workspace) |
| ERR | ERR-1…3 | U (every code has text; per-App isolation) |
| ARC | ARC-1…9 | U/I (state file rebuild, resource present); ARC-1/2/5 verified by review checklist test (protocol docs contain "Happy path"/"Errors") |
| TST | TST-1…5 | `SpecCoverageTests` and registry tests |

Manual checks (cannot be automated hermetically): Gatekeeper first-launch of an installed App; real Login Item approval flow; a live update of one real App on an external volume.

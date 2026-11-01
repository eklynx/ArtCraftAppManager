# Continuous integration and releases

Workflows live in `.github/workflows/`. Requirements: REQ-TST-6 to REQ-TST-8 in [`specs/09-test-plan.md`](specs/09-test-plan.md).

| Workflow | Runs | What it does |
|---|---|---|
| Run Unit Tests (`unit-tests.yml`) | push to `main`, pull requests, manual, called by Release | `xcodebuild test` for `ArtCraftAppManagerTests` only. On `main` pushes it also uploads an **unsigned** zipped app named with the dev version. |
| Run UI Tests (`ui-tests.yml`) | manual only | `xcodebuild test` for `ArtCraftAppManagerUITests` only. Needs a logged-in GUI session, so it defaults to a self-hosted Mac. |
| Release (`release.yml`) | manual only | Runs the unit tests, then signs with Developer ID, notarizes, staples, packages a DMG and creates a GitHub release. |
| Nightly Build (`nightly.yml`) | 03:00 UTC daily, manual | Skips the build when `main` is unchanged since the latest nightly (manual runs have a `force` input). Runs the unit tests, then the same full signing, notarization and stapling as Release, and publishes a GitHub **pre-release** tagged `nightly-<version>`. Only the last 7 nightly pre-releases are kept; older ones are deleted with their tags. |
| Package (`package.yml`) | called by the two above | Shared sign, notarize, staple and DMG steps; the only workflow that reads the signing secrets. |

## Runner
`RUNNER_LABELS` (repository variable, JSON) picks the runner, for example `["xcode-26"]` or `["self-hosted","macOS"]`. Unit tests and Release default to `xcode-26`. Run UI Tests also takes a `runner_labels` input. Optional variable `XCODE_VERSION` (for example `27.0`) selects `/Applications/Xcode_<version>.app`.

## Versioning
Computed by `scripts/compute-version.sh` from the `vX.Y.Z` git tags (nothing is committed back).
- **Manager release**: `X.Y.Z`, the latest tag with the `bump` input (`patch` default, `minor`, `major`) applied. The first release is `1.0.0`.
- **Every other build**: `X.Y.Z-<UTC timestamp>.<short hash>`, where `X.Y.Z` is the latest tag with its patch incremented (`1.0.0` with no tag).
- `CFBundleShortVersionString` cannot hold the `-suffix`, so the app's `MARKETING_VERSION` is always the plain `X.Y.Z`; the full string names the artifact. The build number is the workflow run number.
- Pushing a tag by hand triggers nothing. Release creates the tag.

## Setting up signing (once)
Repository secrets:
- `DEVELOPER_ID_CERT_P12`: base64 of the exported "Developer ID Application" certificate with its private key (`base64 -i cert.p12 | pbcopy`).
- `DEVELOPER_ID_CERT_PASSWORD`: the password used when exporting the .p12.
- `KEYCHAIN_PASSWORD`: any random string; protects the temporary keychain on the runner.
- `NOTARY_API_KEY_P8`: base64 of an App Store Connect API key (`.p8`) allowed to notarize.
- `NOTARY_API_KEY_ID` and `NOTARY_API_ISSUER_ID`: that key's ID and its issuer ID.

## Cutting a release
1. Actions tab, **Release**, **Run workflow**, choose the bump.
2. Expect: unit tests pass, then the notarization wait (usually a few minutes), then a GitHub release `vX.Y.Z` with `ArtCraftAppManager-X.Y.Z.dmg` and a `.sha256` file.
3. Download the DMG on a Mac that never built the app, open it, drag the app out and launch it. Gatekeeper should open it without a warning.
4. Report back anything that failed, with the failing step's log.

## Nightly builds
Download the DMG from the pre-release on the Releases page. Nightlies are never marked latest and carry no `vX.Y.Z` tag, so they don't affect version numbering. Only the last 7 nightlies are kept; to keep a build, run **Release** instead.

## Local checks
- `scripts/tests/compute-version-tests.sh` tests the version rules.
- `scripts/package-dmg.sh App.app out.dmg` makes a DMG locally.

## CodeQL
`codeql.yml` replaces GitHub's default setup (which must stay off, or it rejects these uploads). It scans the workflows (`actions`) on every push and PR to `main` and weekly. Swift is opt-in: set the repository variable `CODEQL_SWIFT` to `true`. Swift needs a traced build, and on the hosted runners CodeQL's tracer fails with this project (autobuild segfaults; a manual `xcodebuild` fails with "Bad CPU type in executable" loading Xcode 27's macro plugin server). Swift does not support `build-mode: none`. Try it with `RUNNER_LABELS` pointing at a self-hosted Mac.


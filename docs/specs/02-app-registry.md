# 02 — App Registry (`REG`)

The *Registry* is `docs/registry/apps.json` (schema: `apps.schema.json`). It lists every App and where its Releases live on GitHub.

## File format
Top level: `schemaVersion` (int, currently `1`), `updated` (date), `owner` (GitHub org), `apps` (array).

Per app:

| Field | Meaning |
|---|---|
| `id` | Stable lowercase key; also the repo name |
| `displayName` | Name shown in UI |
| `repo` | `owner/name` on GitHub |
| `releasesUrl` | Human-facing releases page |
| `apiLatestUrl` | `…/releases/latest` API endpoint |
| `tagPattern` | Regex, named group `version`, matched against the release tag |
| `assetPattern` | Regex, named group `version`, matching the macOS `.dmg` asset name |
| `checksumAsset` | Name of a SHA-256 list asset, or `null` |
| `bundleId` | App's `CFBundleIdentifier`, taken from the app's source repo (13 Craft apps: `packaging/macos/Info.plist.in` → `ai.storyteller.<id>`; ArtCraft: Tauri `identifier` in `crates/desktop/artcraft/tauri.conf.json` → `ai.artcraft.app`). May be `null` only for a future app whose ID isn't known yet |
| `appBundleName` | `.app` folder name inside the DMG (derived from `CFBundleName`/`CFBundleExecutable` in the source plist or Tauri `productName`; the source is trusted) |
| `iconUrl` | Optional icon; `null` → fallback glyph (or the icon of the installed app) |
| `enabledByDefault` | Initial value of the "show in main window" setting |

Naming differs: ArtCraft uses tag `artcraft-vX.Y.Z` and asset `ArtCraft_X.Y.Z_universal.dmg` with no checksum file; the other 13 use tag `vX.Y.Z`, asset `<id>-X.Y.Z-macos-universal.dmg` and `SHA256SUMS.txt`.

## Requirements
- **REQ-REG-1** A copy of `apps.json` MUST ship in the app bundle as the baseline.
- **REQ-REG-2** On launch (and on each refresh) the Manager SHOULD fetch the remote copy from `https://raw.githubusercontent.com/eklynx/ArtCraftAppManager/main/docs/registry/apps.json` and cache it in the state file.
- **REQ-REG-3** A remote copy MUST be used only if it validates against the schema AND its `schemaVersion` is supported. Otherwise the cached copy, then the bundled copy, is used, silently (logged, no status text).
- **REQ-REG-4** An installed App missing from the active registry MUST remain listed as "no longer in registry" with only Run, Open Location and Uninstall available (no Update).
- **REQ-REG-5** Duplicate `id` values in a registry make it invalid (REQ-REG-3 applies).
- **REQ-REG-6** Release resolution uses `GET apiLatestUrl`, which GitHub defines as the newest non-draft, non-prerelease release. Drafts and pre-releases MUST be ignored.
- **REQ-REG-7** The release is usable only if its tag matches `tagPattern` and exactly one asset matches `assetPattern`. Otherwise the App is reported with error `releaseUnusable` (see [07](07-errors-and-status.md)) and treated as having no update.
- **REQ-REG-8** Versions compare as dotted numeric semver (`major.minor.patch`), numerically per component. An update is available only when the release version is strictly greater than the installed `CFBundleShortVersionString`.
- **REQ-REG-9** Requests MUST use conditional requests (`If-None-Match` with the stored ETag); a `304` counts as "no change" and costs no rate limit.
- **REQ-REG-10** On HTTP `403`/`429` with an exhausted rate limit the Manager MUST stop checking until `X-RateLimit-Reset`, show `rateLimited`, and keep previously known results.
- **REQ-REG-11** An optional GitHub token MAY be stored in the Keychain to raise the limit; the app works without it.
- **REQ-REG-12** Update checks run: at launch, every 6 hours while the Manager is running, and on manual Refresh. A scheduled check MUST NOT start while another is in flight.

## Error cases
Network failure → `offline`; malformed JSON/schema → fall back (REQ-REG-3); no matching asset → `releaseUnusable`; rate limit → `rateLimited`.

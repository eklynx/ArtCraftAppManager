# 10 — Manager update (`UPD`)

The Manager updates itself with [Sparkle](https://sparkle-project.org). The *Feed* is a Sparkle appcast hosted on GitHub Pages and rebuilt by a GitHub Action. "Update" in other specs means an App's update; this spec is about *Manager updates* only.

## Channels
| Channel | Offers | Sparkle channel names allowed |
|---|---|---|
| Release (default) | Manager releases (`vX.Y.Z`) | none (items without a channel) |
| Pre-release | Releases and GitHub pre-releases whose tag does not start with `nightly-` | `prerelease` |
| Nightly | Everything, including Nightly builds (`nightly-*` pre-releases) | `prerelease`, `nightly` |

## Requirements
- **REQ-UPD-1** The Manager checks the Feed at `https://eklynx.github.io/ArtCraftAppManager/appcast.xml` (Info.plist `SUFeedURL`) with Sparkle, verifying updates against the EdDSA public key in `SUPublicEDKey`. All Sparkle use is behind the `ManagerUpdating` protocol; `UI/` never touches Sparkle.
- **REQ-UPD-2** Channels are cumulative as in the table above. The chosen channel is stored in `UserDefaults` (`managerUpdateChannel`, default `release`) and takes effect on the next check.
- **REQ-UPD-3** The app menu has **Check for Updates…** directly under **About**, running a user-initiated check with Sparkle's standard dialog.
- **REQ-UPD-4** Settings has a **Manager Updates** section with **Automatically check for Manager updates** (`managerAutoCheck`, default on) and an **Update channel** picker. Automatic checks run on launch and daily, always ask before installing, and never download or install silently.
- **REQ-UPD-5** Builds are ordered by `CFBundleVersion`. CI sets it to the UTC build time `yyyyMMddHHmmss`, so it rises across the separate Release and Nightly workflows. The marketing version stays plain `X.Y.Z`.
- **REQ-UPD-6** Debug builds and test runs use `DisabledManagerUpdater`: no network, no dialogs.
- **REQ-UPD-7** The workflow `appcast.yml` rebuilds the Feed whenever Release or Nightly Build completes successfully (and on demand). `scripts/build-appcast.py` downloads every Manager DMG, signs it with `generate_appcast` using the `SPARKLE_ED_PRIVATE_KEY` secret, tags each item with its channel and merges the items into one `appcast.xml`, deployed to GitHub Pages. Items without an EdDSA signature (builds from before Sparkle) are left out. A Nightly pruned by the 7-build retention disappears from the Feed on the next run.
- **REQ-UPD-8** The private key never enters the repository. It lives in the 1Password vault `Dev-ArtCraftAppManager` (item `SPARKLE_ED_PRIVATE_KEY`) and in the GitHub Actions secret of the same name.
- **REQ-UPD-9** Existing Manager copies have no updater; the first Sparkle-enabled build must be installed by hand.

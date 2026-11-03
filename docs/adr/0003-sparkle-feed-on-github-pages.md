# 0003 — Sparkle self-update with the Feed on GitHub Pages

The Manager updates itself with Sparkle. The appcast is regenerated from the GitHub releases by a workflow and deployed to GitHub Pages, so the feed URL is stable and the repo history has no bot commits. Three opt-in channels (Release, Pre-release, Nightly) map to Sparkle channels; builds are ordered by a UTC-timestamp `CFBundleVersion` because `github.run_number` is per workflow and cannot order Release against Nightly builds.

Rejected: committing `appcast.xml` to `main` or `gh-pages` (bot commits, cache delay on raw URLs); a hand-rolled updater (Sparkle already does signature checks, relaunch and the update UI). Hard to reverse because shipped builds embed the Feed URL and public key: changing either strands existing installs.

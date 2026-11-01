# 0002 — Registry bundled with remote refresh

The list of Apps and their GitHub release locations is a JSON file in this repo. A copy is bundled as the baseline; the Manager also fetches the `main` copy and caches it, using it only if it validates and its `schemaVersion` is supported (otherwise silent fallback).

This lets new Apps appear without shipping a Manager build, while a bad or unreachable remote file can never break the app. Rejected: bundled-only (needs a release per new App); discovering Apps by listing the `storytold` org (no reliable way to tell Apps from libraries, and it would pull in non-macOS projects).

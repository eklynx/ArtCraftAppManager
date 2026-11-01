# 01 — Overview (`OVR`)

## Purpose
The ArtCraft launcher distributed by the vendor only manages applications under `/Applications`. The built-in drive of the primary user is too small for the suite, so the apps live on a second drive. The *Manager* installs, updates, runs and uninstalls ArtCraft suite *Apps* wherever they are installed, and notifies about (and optionally performs) updates.

## Goals
- **REQ-OVR-1** The Manager MUST install an App to any user-chosen folder, defaulting to the *Default Install Location*.
- **REQ-OVR-2** The Manager MUST detect Apps already installed anywhere on local volumes and show their version and location.
- **REQ-OVR-3** The Manager MUST detect newer *Releases* on GitHub and offer, or perform, the update at the App's existing location.
- **REQ-OVR-4** The set of Apps comes from the [registry](02-app-registry.md), not from code.

## Non-goals
- Managing Windows/Linux builds, CLI/web artefacts, or `craft-launcher` and `craft-anything`.
- Pre-release channels (v1).
- Installing to or managing anything inside the user's data/preferences of an App.
- Mac App Store distribution (see [ADR 0001](../adr/0001-sandbox-and-install-strategy.md)).

## Platform
- macOS 27+ (project deployment target), SwiftUI, Swift.
- Only the `macos-universal` `.dmg` of a Release is used.
- Single user, single machine; no accounts or server component.

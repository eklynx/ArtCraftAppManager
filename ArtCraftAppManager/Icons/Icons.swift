// SOURCE OF TRUTH (for humans and AI agents): the `Icons` namespace contract.
// Types: AppIconProviding.
// Implementations: GitHubIconProvider.swift, IconChoice.swift.
// Read the doc comments on each protocol (happy path + errors) before calling into this namespace,
// and the governing spec: docs/specs/04-main-window.md (REQ-WIN-25). Other namespaces MUST go through these protocols.

import AppKit
import Foundation

/// Supplies the icon image of an App that is not installed.
///
/// **Happy path:** returns PNG/image data for the App's `iconUrl`, from the on-disk cache when it is less than a day old,
/// otherwise downloaded (conditional on the stored ETag) and cached.
/// **Errors:** none are thrown. Offline, non-200, non-image, oversize or missing `iconUrl` return the stale cached copy if one
/// exists, else `nil` (the UI then shows the placeholder). A bad file is never cached.
protocol AppIconProviding {
    func icon(for app: RegistryApp) async -> Data?
}

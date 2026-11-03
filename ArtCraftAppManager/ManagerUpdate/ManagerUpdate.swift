// SOURCE OF TRUTH (for humans and AI agents): the `ManagerUpdate` namespace contract.
// Types: ManagerUpdateChannel, ManagerUpdating.
// Implementations: SparkleManagerUpdater.swift (production), DisabledManagerUpdater.swift (Debug and test runs).
// Read the doc comments below (happy path + errors) before calling into this namespace,
// and the governing spec: docs/specs/10-manager-update.md. Other namespaces MUST go through these protocols.

import Foundation

/// Which Manager builds the user is offered (REQ-UPD-2). Channels are cumulative: a wider channel also sees the narrower ones.
enum ManagerUpdateChannel: String, CaseIterable, Identifiable, Sendable {
    /// Manager releases (`vX.Y.Z`). The default.
    case release
    /// Manager releases plus GitHub pre-releases whose tag does not start with `nightly-`.
    case prerelease
    /// Everything: releases, pre-releases and Nightly builds.
    case nightly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .release: "Release"
        case .prerelease: "Pre-release"
        case .nightly: "Nightly"
        }
    }

    /// The Sparkle channel names this channel opts in to. Items with no `<sparkle:channel>` (Manager releases) are always offered.
    var sparkleChannels: Set<String> {
        switch self {
        case .release: []
        case .prerelease: ["prerelease"]
        case .nightly: ["prerelease", "nightly"]
        }
    }
}

/// Updates the Manager itself from the Feed (REQ-UPD-1).
///
/// **Happy path:** `checkForUpdates()` shows the standard update dialog; the user chooses to install, the Manager relaunches.
/// Automatic checks run on launch and daily while `automaticallyChecks` is on, and always ask before installing.
/// **Errors:** none thrown. An unreachable or invalid Feed, a bad signature or a failed install is reported to the user
/// by the update dialog and leaves the running Manager untouched.
protocol ManagerUpdating: AnyObject {
    /// False while a check or install is already in progress, or when the updater is disabled.
    @MainActor var canCheckForUpdates: Bool { get }
    @MainActor var automaticallyChecks: Bool { get set }
    @MainActor var channel: ManagerUpdateChannel { get set }
    /// User-initiated check ("Check for Updates…").
    @MainActor func checkForUpdates()
}

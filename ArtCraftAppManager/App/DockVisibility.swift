// SOURCE OF TRUTH (for humans and AI agents): the Dock-icon visibility contract (REQ-WIN-29).
// Types: ActivationPolicyControlling.
// Implementations: SystemActivationPolicySetter.swift (production), DockVisibilityController.swift (decides when to call it).
// The rule itself is `AppLifecyclePolicy.hidesDockIcon` in UI/ViewModels.swift. Governing spec: docs/specs/04-main-window.md.

import Foundation

/// Shows or hides the Manager's Dock icon (`NSApp.setActivationPolicy` in production).
///
/// **Happy path:** `setDockIconVisible(true)` makes the app a regular app (Dock icon, app menu, Cmd-Tab) and activates it;
/// `setDockIconVisible(false)` makes it an accessory app that lives only in the menu bar. Calling it with the current state does nothing.
/// **Errors:** none thrown. If the system refuses the change the Dock icon simply stays as it was.
protocol ActivationPolicyControlling: AnyObject {
    @MainActor func setDockIconVisible(_ visible: Bool)
}

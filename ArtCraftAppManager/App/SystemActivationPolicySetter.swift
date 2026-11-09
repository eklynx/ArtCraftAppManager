import AppKit

/// `NSApp.setActivationPolicy`-backed Dock icon control (REQ-WIN-29). Not `LSUIElement`: that would hide the icon permanently.
final class SystemActivationPolicySetter: ActivationPolicyControlling {
    @MainActor func setDockIconVisible(_ visible: Bool) {
        let wanted: NSApplication.ActivationPolicy = visible ? .regular : .accessory
        guard NSApp.activationPolicy() != wanted else { return }
        NSApp.setActivationPolicy(wanted)
        if visible { NSApp.activate(ignoringOtherApps: true) }
    }
}

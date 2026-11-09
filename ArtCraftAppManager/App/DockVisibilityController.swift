import AppKit

/// Keeps the Dock icon in step with the open windows (REQ-WIN-29): hidden when "Launch at login" is on and no Manager
/// window is open, visible otherwise. The main window and Settings both count as windows.
@MainActor
final class DockVisibilityController {
    private let policy: ActivationPolicyControlling
    private let launchAtLogin: () -> Bool
    private let visibleWindowCount: () -> Int
    private var observers: [NSObjectProtocol] = []

    init(policy: ActivationPolicyControlling,
         launchAtLogin: @escaping () -> Bool,
         visibleWindowCount: @escaping () -> Int = DockVisibilityController.countRealWindows) {
        self.policy = policy
        self.launchAtLogin = launchAtLogin
        self.visibleWindowCount = visibleWindowCount
    }

    /// Windows a user can see and work in: not the status item's window or other panels.
    static func countRealWindows() -> Int {
        NSApp.windows.filter { $0.isVisible && !($0 is NSPanel) && $0.canBecomeMain }.count
    }

    /// Applies the launch state, then follows window and setting changes.
    func start(startedByLoginItem: Bool) {
        policy.setDockIconVisible(AppLifecyclePolicy.startsWithDockIcon(startedByLoginItem: startedByLoginItem, launchAtLogin: launchAtLogin()))
        let center = NotificationCenter.default
        for name in [NSWindow.didBecomeKeyNotification, NSWindow.didBecomeMainNotification, NSWindow.willCloseNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                // willClose fires while the closing window still reports visible; look again after it is gone.
                DispatchQueue.main.async { MainActor.assumeIsolated { self?.update() } }
            })
        }
        observers.append(center.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.update() }
        })
    }

    func update() {
        let hide = AppLifecyclePolicy.hidesDockIcon(launchAtLogin: launchAtLogin(), hasVisibleWindows: visibleWindowCount() > 0)
        policy.setDockIconVisible(!hide)
    }
}

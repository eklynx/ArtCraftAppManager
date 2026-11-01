import Foundation

final class UpdateNotificationService {
    private let notifier: UpdateNotifying
    private let state: ManagerStateStoring
    private var allowed = true

    init(notifier: UpdateNotifying, state: ManagerStateStoring) {
        self.notifier = notifier
        self.state = state
    }

    /// Requests permission (REQ-NOT-1).
    func start() async {
        allowed = await notifier.requestAuthorization()
    }

    /// Posts at most once per App, version and kind (REQ-NOT-3); degrades to a badge when denied (REQ-NOT-1).
    func deliver(_ kind: NotificationKind, app: RegistryApp, version: String) async -> DeliveryOutcome {
        let key = "\(kind.rawValue)|\(app.id)|\(version)"
        var current = state.load()
        guard current.notified.insert(key).inserted else { return .suppressedDuplicate }
        try? state.save(current)
        guard allowed else { return .badgeOnly }
        await notifier.post(kind: kind, appId: app.id, appName: app.displayName, version: version)
        return .posted
    }

    /// The App id whose row a clicked notification should bring into view (REQ-NOT-2).
    func rowToReveal(forClickedNotificationOf appId: String) -> String? {
        appId.isEmpty ? nil : appId
    }
}

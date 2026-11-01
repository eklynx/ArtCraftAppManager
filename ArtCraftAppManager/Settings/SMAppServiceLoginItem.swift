import Foundation
import ServiceManagement

/// Registers the Manager as a login item (REQ-SET-6).
struct SMAppServiceLoginItem: LoginItemControlling {
    func setEnabled(_ enabled: Bool) throws {
        if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
    }
}

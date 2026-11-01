import AppKit
import Foundation

/// Which icon a row or Settings entry shows (REQ-WIN-25 precedence).
enum IconChoice: Equatable {
    case installed, cached, placeholder

    static func source(installed: Bool, cached: Bool) -> IconChoice {
        installed ? .installed : (cached ? .cached : .placeholder)
    }
}

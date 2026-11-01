import AppKit
import Foundation

/// Moves items to the user's Trash.
struct FileManagerTrasher: Trashing {
    func moveToTrash(_ url: URL) throws {
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }
}

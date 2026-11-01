import Foundation

enum FolderValidator {
    /// - Throws: `.folderMissing` if the folder does not exist, `.permissionDenied` if it is not writable (REQ-SET-2).
    static func validate(_ folder: URL) throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw ManagerError.folderMissing(folder: folder.path)
        }
        guard FileManager.default.isWritableFile(atPath: folder.path) else {
            throw ManagerError.permissionDenied(folder: folder.path)
        }
    }
}

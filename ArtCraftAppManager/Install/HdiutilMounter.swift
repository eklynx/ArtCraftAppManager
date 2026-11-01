import CryptoKit
import Foundation

/// `hdiutil`-backed mounter (REQ-TST-5 integration).
struct HdiutilMounter: DiskImageMounting {
    func mount(_ dmg: URL, app: String) throws -> URL {
        let output = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["attach", "-nobrowse", "-readonly", "-noautoopen", "-plist", dmg.path]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { throw ManagerError.mountFailed(app: app) }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let entities = plist["system-entities"] as? [[String: Any]],
              let mountPath = entities.compactMap({ $0["mount-point"] as? String }).first
        else { throw ManagerError.mountFailed(app: app) }
        return URL(fileURLWithPath: mountPath)
    }

    func unmount(_ mountPoint: URL) {
        for arguments in [["detach", "-quiet", mountPoint.path], ["detach", "-quiet", "-force", mountPoint.path]] {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
            process.arguments = arguments
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            if (try? process.run()) != nil { process.waitUntilExit() }
            if process.terminationStatus == 0 { return }
        }
    }
}

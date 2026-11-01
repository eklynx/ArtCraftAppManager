import AppKit
import Foundation

/// Finds installed apps by bundle ID via LaunchServices and Spotlight, and reports running apps.
enum SystemAppLookup {
    static func urls(forBundleID id: String) -> [URL] {
        var found = NSWorkspace.shared.urlsForApplications(withBundleIdentifier: id)
        found += spotlight(bundleID: id)
        var seen = Set<String>()
        return found.filter { seen.insert($0.standardizedFileURL.path).inserted }
    }

    static func runningBundleIDs() -> Set<String> {
        Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
    }

    private static func spotlight(bundleID: String) -> [URL] {
        let process = Process(), pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        process.arguments = ["kMDItemCFBundleIdentifier == '\(bundleID)'"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self).split(separator: "\n").map { URL(fileURLWithPath: String($0)) }
    }
}

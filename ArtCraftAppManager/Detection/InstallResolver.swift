import Foundation

enum InstallResolver {
    /// Chooses which copy the row shows: the recorded path, else the highest version (REQ-INS-3).
    static func resolve(copies: [InstalledApp], recordedPath: URL?) -> ResolvedInstall? {
        guard !copies.isEmpty else { return nil }
        let shown = copies.first { $0.url.standardizedFileURL == recordedPath?.standardizedFileURL }
            ?? copies.max { $0.version < $1.version }!
        return ResolvedInstall(shown: shown, others: copies.filter { $0 != shown })
    }
}

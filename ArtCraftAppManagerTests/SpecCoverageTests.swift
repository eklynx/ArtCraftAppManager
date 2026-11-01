import Foundation
import Testing
@testable import ArtCraftAppManager

// docs/specs/09-test-plan.md — REQ-TST-1

struct SpecCoverageTests {
    private static let idPattern = try! NSRegularExpression(pattern: #"REQ[-_][A-Z]+[-_][0-9]+"#)

    private static func ids(in text: String) -> Set<String> {
        Set(idPattern.matches(in: text, range: NSRange(text.startIndex..., in: text)).map { String(text[Range($0.range, in: text)!]).replacingOccurrences(of: "_", with: "-") })
    }

    private static let definition = try! NSRegularExpression(pattern: #"\*\*(REQ-[A-Z]+-[0-9]+)\*\*"#)

    /// IDs defined in the specs (a definition is `**REQ-X-n**`), excluding withdrawn ones.
    static func specIds() throws -> Set<String> {
        var result = Set<String>()
        let files = try FileManager.default.contentsOfDirectory(at: Repo.specs, includingPropertiesForKeys: nil).filter { $0.pathExtension == "md" }
        for file in files {
            for line in try String(contentsOf: file, encoding: .utf8).components(separatedBy: "\n") where !line.contains("(withdrawn)") {
                for m in definition.matches(in: line, range: NSRange(line.startIndex..., in: line)) {
                    result.insert(String(line[Range(m.range(at: 1), in: line)!]))
                }
            }
        }
        return result
    }

    static func testedIds() -> Set<String> {
        var result = Set<String>()
        for dir in [Repo.unitTests, Repo.uiTests] {
            for file in Repo.swiftFiles(in: dir) where file.lastPathComponent != "SpecCoverageTests.swift" {
                result.formUnion(ids(in: (try? String(contentsOf: file, encoding: .utf8)) ?? ""))
            }
        }
        return result
    }

    @Test("REQ-TST-1 every REQ id in the specs is referenced by at least one test")
    func everyRequirementHasATest() throws {
        let defined = try Self.specIds()
        #expect(defined.count >= 80)
        let missing = defined.subtracting(Self.testedIds()).sorted()
        #expect(missing.isEmpty, "Requirements without a test: \(missing.joined(separator: ", "))")
    }

    @Test("REQ-TST-1 tests reference no requirement that the specs do not define")
    func noOrphanReferences() throws {
        let orphans = Self.testedIds().subtracting(try Self.specIds().union(allMentionedInSpecs())).sorted()
        #expect(orphans.isEmpty, "Unknown requirement ids in tests: \(orphans.joined(separator: ", "))")
    }

    private func allMentionedInSpecs() throws -> Set<String> {
        var result = Set<String>()
        for file in try FileManager.default.contentsOfDirectory(at: Repo.specs, includingPropertiesForKeys: nil) where file.pathExtension == "md" {
            result.formUnion(Self.ids(in: try String(contentsOf: file, encoding: .utf8)))
        }
        return result
    }
}

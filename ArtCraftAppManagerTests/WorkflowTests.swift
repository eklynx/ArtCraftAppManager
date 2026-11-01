import Foundation
import Testing

// docs/specs/09-test-plan.md — REQ-TST-6, REQ-TST-7, REQ-TST-8

struct WorkflowTests {
    private func workflow(_ name: String) throws -> String {
        try String(contentsOf: Repo.root.appendingPathComponent(".github/workflows/\(name)"), encoding: .utf8)
    }

    @Test("REQ-TST-6 Run Unit Tests runs only the unit test bundle on main, pull requests and demand")
    func unitTestWorkflow() throws {
        let text = try workflow("unit-tests.yml")
        #expect(text.contains("name: Run Unit Tests"))
        #expect(text.contains("-only-testing:ArtCraftAppManagerTests"))
        #expect(!text.contains("ArtCraftAppManagerUITests"))
        for trigger in ["push:", "pull_request:", "workflow_dispatch:", "workflow_call:"] { #expect(text.contains(trigger)) }
        #expect(!text.contains("secrets."))
    }

    @Test("REQ-TST-6 Run UI Tests runs only the UI test bundle, on demand only")
    func uiTestWorkflow() throws {
        let text = try workflow("ui-tests.yml")
        #expect(text.contains("name: Run UI Tests"))
        #expect(text.contains("-only-testing:ArtCraftAppManagerUITests"))
        #expect(text.contains("workflow_dispatch:"))
        for trigger in ["push:", "pull_request:", "schedule:"] { #expect(!text.contains("\n  \(trigger)")) }
    }

    @Test("REQ-TST-6 Release is manual, gated on the unit tests, and signs through the shared package workflow")
    func releaseWorkflow() throws {
        let text = try workflow("release.yml")
        #expect(text.contains("workflow_dispatch:"))
        #expect(!text.contains("\n  push:"))
        #expect(text.contains("uses: ./.github/workflows/unit-tests.yml"))
        #expect(text.contains("needs: unit-tests"))
        #expect(text.contains("uses: ./.github/workflows/package.yml"))
        #expect(text.contains("kind: release"))
        #expect(text.contains("gh release create"))
    }

    @Test("REQ-TST-6 the package workflow fully signs: Developer ID, notarization and stapling")
    func packageWorkflow() throws {
        let text = try workflow("package.yml")
        #expect(text.contains("secrets.DEVELOPER_ID_CERT_P12"))
        #expect(text.contains("notarytool submit"))
        #expect(text.contains("stapler staple"))
        #expect(text.contains("workflow_call:"))
        #expect(!text.contains("\n  push:"))
    }

    @Test("REQ-TST-8 Nightly Build is scheduled, fully signed, published as a pre-release and skipped when unchanged and keeps the last 7")
    func nightlyWorkflow() throws {
        let text = try workflow("nightly.yml")
        #expect(text.contains("schedule:"))
        #expect(text.contains("workflow_dispatch:"))
        #expect(text.contains("uses: ./.github/workflows/package.yml"))
        #expect(text.contains("kind: nightly"))
        #expect(text.contains("--prerelease"))
        #expect(text.contains("--latest=false"))
        #expect(text.contains("startswith(\"nightly-\")"))
        #expect(text.contains(".[7:]"))
        #expect(text.contains("targetCommitish"))
        #expect(text.contains("force:"))
        #expect(text.contains("needs: unit-tests"))
        #expect(!text.contains("secrets.DEVELOPER_ID"))
    }

    @Test("REQ-TST-6 only package.yml uses signing secrets")
    func signingSecretsStayInPackage() throws {
        for name in ["unit-tests.yml", "ui-tests.yml", "release.yml", "nightly.yml"] {
            #expect(!(try workflow(name)).contains("secrets.DEVELOPER_ID"), "\(name)")
        }
    }

    @Test("REQ-TST-6 runner labels come from RUNNER_LABELS and default to xcode-26")
    func runnerSelection() throws {
        for name in ["unit-tests.yml", "package.yml"] {
            #expect(try workflow(name).contains("vars.RUNNER_LABELS || '[\"xcode-26\"]'"))
        }
    }

    @Test("REQ-TST-7 the version script passes its own shell tests")
    func versionScript() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [Repo.root.appendingPathComponent("scripts/tests/compute-version-tests.sh").path]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0, "\(String(decoding: data, as: UTF8.self))")
    }
}

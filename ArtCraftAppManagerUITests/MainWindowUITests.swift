import XCTest

/// XCUITest smoke tests for docs/specs/04-main-window.md and 05-settings.md.
/// Accessibility identifiers used here are part of the UI contract:
/// `appList`, `appRow.<id>`, `toolbar.refresh`, `toolbar.settings`, `statusLine`, `emptyState`,
/// `settings.defaultInstall.choose`, `settings.download.choose`, `settings.apps.list`,
/// `settings.autoDownload`, `settings.autoInstall`, `settings.launchAtLogin`.
final class MainWindowUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    private func launch(arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest"] + arguments
        app.launch()
        return app
    }

    @MainActor
    func test_REQ_WIN_1_listShowsEnabledApps() {
        let app = launch()
        XCTAssertTrue(app.scrollViews["appList"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["appRow.gridcraft"].exists)
    }

    @MainActor
    func test_REQ_WIN_5_REQ_WIN_18_toolbarHasRefreshAndSettings() {
        let app = launch()
        XCTAssertTrue(app.buttons["toolbar.refresh"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["toolbar.settings"].exists)
    }

    @MainActor
    func test_REQ_WIN_6_emptyStateWhenNoAppsEnabled() {
        let app = launch(arguments: ["-uitest-no-enabled-apps"])
        XCTAssertTrue(app.staticTexts["emptyState"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["emptyState"].label, "No applications selected")
    }

    @MainActor
    func test_REQ_WIN_7_REQ_WIN_8_statusLineIsPinnedAtTheBottom() {
        let app = launch(arguments: ["-uitest-offline"])
        let status = app.staticTexts["statusLine"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertEqual(status.label, "Can't reach GitHub. Showing last known versions.")
        XCTAssertGreaterThan(status.frame.minY, app.windows.firstMatch.frame.midY)
    }

    @MainActor
    func test_REQ_WIN_12_REQ_WIN_17_buttonsNameTheirApp() {
        let app = launch(arguments: ["-uitest-installed-gridcraft"])
        XCTAssertTrue(app.buttons["Run GridCraft"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Open Location for GridCraft"].exists)
        XCTAssertTrue(app.buttons["Uninstall GridCraft"].exists)
    }

    @MainActor
    func test_REQ_INS_14_uninstallAsksForConfirmation() {
        let app = launch(arguments: ["-uitest-installed-gridcraft"])
        app.buttons["Uninstall GridCraft"].click()
        let sheet = app.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 5))
        XCTAssertTrue(sheet.staticTexts.matching(NSPredicate(format: "label CONTAINS 'preferences are kept'")).count > 0)
    }

    @MainActor
    func test_REQ_SET_1_REQ_SET_3_settingsWindowHasPickersAndAppList() {
        let app = launch()
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(app.buttons["settings.defaultInstall.choose"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings.download.choose"].exists)
        XCTAssertTrue(app.tables["settings.apps.list"].exists || app.outlines["settings.apps.list"].exists)
    }

    @MainActor
    func test_REQ_SET_4_REQ_SET_7_autoInstallLocksAutoDownload() {
        let app = launch()
        app.typeKey(",", modifierFlags: .command)
        let install = app.checkBoxes["settings.autoInstall"], download = app.checkBoxes["settings.autoDownload"]
        XCTAssertTrue(install.waitForExistence(timeout: 5))
        install.click()
        XCTAssertEqual(download.value as? Int, 1)
        XCTAssertFalse(download.isEnabled)
    }

    @MainActor
    func test_REQ_WIN_9_REQ_WIN_11_loginLaunchHasNoWindowButAMenuBarItem() {
        let app = launch(arguments: ["-uitest-started-by-login-item"])
        XCTAssertEqual(app.windows.count, 0)
        XCTAssertTrue(app.menuBars.statusItems.firstMatch.waitForExistence(timeout: 5))
    }
}

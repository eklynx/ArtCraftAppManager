import XCTest

/// XCUITest smoke tests for docs/specs/04-main-window.md and 05-settings.md.
/// Accessibility identifiers used here are part of the UI contract:
/// `appList`, `appRow.<id>`, `toolbar.refresh`, `toolbar.settings`, `statusLine`, `emptyState`,
/// `settings.defaultInstall.choose`, `settings.download.choose`, `settings.apps.list`,
/// `settings.autoDownload`, `settings.autoInstall`, `settings.launchAtLogin`.
final class MainWindowUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    /// macOS static texts expose their string as `value`; fall back to `label`.
    private func text(of element: XCUIElement) -> String {
        (element.value as? String).flatMap { $0.isEmpty ? nil : $0 } ?? element.label
    }

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
        XCTAssertTrue(app.descendants(matching: .any)["appRow.gridcraft"].exists)
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
        XCTAssertEqual(text(of: app.staticTexts["emptyState"]), "No applications selected")
    }

    @MainActor
    func test_REQ_WIN_7_REQ_WIN_8_statusLineIsPinnedAtTheBottom() {
        let app = launch(arguments: ["-uitest-offline"])
        let status = app.staticTexts["statusLine"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertEqual(text(of: status), "Can't reach GitHub. Showing last known versions.")
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
        let kept = NSPredicate(format: "label CONTAINS 'preferences are kept' OR value CONTAINS 'preferences are kept'")
        XCTAssertTrue(sheet.staticTexts.matching(kept).count > 0)
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
    func test_REQ_SET_9_githubTokenIsHiddenUnlessOptionIsHeld() {
        let app = launch()
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(app.buttons["settings.defaultInstall.choose"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.secureTextFields["settings.githubToken"].exists)
        app.typeKey("w", modifierFlags: .command)  // close Settings

        XCUIElement.perform(withKeyModifiers: .option) { app.buttons["toolbar.settings"].click() }
        XCTAssertTrue(app.secureTextFields["settings.githubToken"].waitForExistence(timeout: 5))
    }

    @MainActor
    func test_REQ_SET_11_REQ_SET_12_contextMenuReordersAndResetRestoresTheDefault() {
        let app = launch()
        app.typeKey(",", modifierFlags: .command)
        let reset = app.buttons["settings.apps.resetOrder"]
        XCTAssertTrue(reset.waitForExistence(timeout: 5))
        XCTAssertFalse(reset.isEnabled, "Reset Order is disabled while the order is the default")

        let rows = app.descendants(matching: .any)["settings.apps.list"].cells
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5))
        rows.element(boundBy: 0).rightClick()
        app.menuItems["Move Down"].click()
        XCTAssertTrue(reset.isEnabled, "moving a row changes the App order")

        reset.click()
        XCTAssertFalse(reset.isEnabled)
    }

    // Dragging a row (REQ-SET-11) is checked by hand: XCUITest's synthetic drag is not recognised by the list.

    @MainActor
    func test_REQ_SET_4_REQ_SET_7_autoInstallLocksAutoDownload() {
        let app = launch()
        app.typeKey(",", modifierFlags: .command)
        let install = app.descendants(matching: .any)["settings.autoInstall"]
        let download = app.switches["settings.autoDownload"]
        XCTAssertTrue(install.waitForExistence(timeout: 5))
        install.click()
        XCTAssertEqual("\(download.value ?? "")", "1")
        XCTAssertFalse(download.isEnabled)
    }

    @MainActor
    func test_REQ_WIN_9_REQ_WIN_11_loginLaunchHasNoWindowButAMenuBarItem() {
        let app = launch(arguments: ["-uitest-started-by-login-item"])
        XCTAssertEqual(app.windows.count, 0)
        XCTAssertTrue(app.menuBars.statusItems.firstMatch.waitForExistence(timeout: 5))
    }
}

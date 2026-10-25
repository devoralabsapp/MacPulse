import XCTest

final class MacPulseUITests: XCTestCase {
    @MainActor func testBatteryReportImportEntryOpensFilesPicker() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-appLanguage", "en"]
        app.launch()
        navigate("Overview", app: app)
        let button = app.buttons["battery.import"]
        for _ in 0..<10 {
            if button.exists && button.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(button.exists); XCTAssertTrue(button.isHittable)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Battery-report-import"; screenshot.lifetime = .keepAlways; add(screenshot)
        button.tap()
        // Document-provider UI follows the OS language, independently of MacPulse's language.
        let cancel = app.buttons.matching(NSPredicate(format: "label IN %@", ["Cancel", "Hủy"])).firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 10))
        cancel.tap()
        XCTAssertTrue(button.waitForExistence(timeout: 5))
    }

    @MainActor func testAdaptiveNavigationAndPersistedAppearance() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-appLanguage", "en"]
        app.launch()
        if !app.scrollViews["screen.overview"].waitForExistence(timeout: 3) { navigate("Overview", app: app) }
        XCTAssertTrue(app.scrollViews["screen.overview"].waitForExistence(timeout: 10))
        navigate("Settings", app: app)
        let violet = app.buttons["theme.violet"]
        XCTAssertTrue(violet.waitForExistence(timeout: 5)); violet.tap()
        reveal(app.staticTexts["theme.selected"], app: app)
        XCTAssertTrue(app.staticTexts["theme.selected"].label.contains("Violet"))
        let dark = app.segmentedControls["appearance.mode"].buttons["Dark"]
        XCTAssertTrue(dark.exists); dark.tap()
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Appearance-dark"; attachment.lifetime = .keepAlways; add(attachment)
        app.terminate(); app.launch()
        navigate("Settings", app: app)
        XCTAssertTrue(app.staticTexts["theme.selected"].waitForExistence(timeout: 10))
        reveal(app.staticTexts["theme.selected"], app: app)
        XCTAssertTrue(app.staticTexts["theme.selected"].label.contains("Violet"))
        XCTAssertTrue(app.segmentedControls["appearance.mode"].buttons["Dark"].isSelected)
        navigate("Network", app: app)
        XCTAssertTrue(app.scrollViews["screen.network"].waitForExistence(timeout: 5))
        navigate("Cleanup", app: app)
        XCTAssertTrue(app.buttons["files.choose"].waitForExistence(timeout: 5))
        navigate("Overview", app: app)
        let overview = XCTAttachment(screenshot: app.screenshot())
        overview.name = "Overview-adaptive"; overview.lifetime = .keepAlways; add(overview)
    }
    @MainActor func testVietnameseAppearanceAndNavigation() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-appLanguage", "vi", "-themePreset", "forest", "-themeAppearance", "light"]
        app.launch()
        navigate("Tổng quan", page: "overview", app: app)
        XCTAssertTrue(app.staticTexts["CPU của app"].waitForExistence(timeout: 10))
        navigate("Cài đặt", page: "settings", app: app)
        reveal(app.staticTexts["theme.selected"], app: app)
        XCTAssertTrue(app.staticTexts["theme.selected"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["theme.selected"].label.hasPrefix("Bảng màu đang dùng:"))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Vietnamese-appearance"; screenshot.lifetime = .keepAlways; add(screenshot)
        navigate("Mạng", page: "network", app: app)
        XCTAssertTrue(app.scrollViews["screen.network"].waitForExistence(timeout: 5))
        navigate("Dọn dẹp", page: "cleanup", app: app)
        XCTAssertTrue(app.buttons["files.choose"].waitForExistence(timeout: 5))
    }
    @MainActor private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<4 {
            if element.exists { return }
            app.swipeUp()
        }
    }
    @MainActor private func navigate(_ title: String, page: String? = nil, app: XCUIApplication) {
        if app.tabBars.buttons[title].exists { app.tabBars.buttons[title].tap() }
        else {
            let button = app.buttons["page.\(page ?? title.lowercased())"]
            if !button.exists {
                let sidebar = app.navigationBars.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'sidebar'")).firstMatch
                if sidebar.exists { sidebar.tap() }
            }
            if button.exists { button.tap() } else { app.buttons[title].firstMatch.tap() }
        }
    }
}

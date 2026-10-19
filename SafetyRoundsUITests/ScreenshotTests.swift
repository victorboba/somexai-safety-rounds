import XCTest

/// Captures App Store screenshots. Run with scripts/screenshots.sh SafetyRounds.
final class ScreenshotTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testAppScreens() {
        let app = XCUIApplication()
        app.launchArguments = ["-unlock", "-resetData", "-sampleData", "-skipOnboarding", "-uiTesting"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Due"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["EXT-03"].waitForExistence(timeout: 10))
        snap("01-due", app)

        app.staticTexts["EXT-03"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Inspect"].waitForExistence(timeout: 5))
        snap("02-checklist", app)
        app.buttons["Cancel"].tap()

        app.tabBars.buttons["Equipment"].tap()
        XCTAssertTrue(app.navigationBars["Equipment"].waitForExistence(timeout: 5))
        snap("03-equipment", app)

        app.staticTexts["AED-01"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Show QR label"].waitForExistence(timeout: 5))
        snap("04-asset", app)
        app.buttons["Show QR label"].tap()
        XCTAssertTrue(app.navigationBars["QR Label"].waitForExistence(timeout: 5))
        snap("05-qr-label", app)
        app.buttons["Done"].tap()

        app.tabBars.buttons["Report"].tap()
        XCTAssertTrue(app.navigationBars["Report"].waitForExistence(timeout: 5))
        snap("06-report", app)
    }

    func testPaywall() {
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-uiTesting", "-mockPrices"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Lifetime"].waitForExistence(timeout: 10))
        snap("paywall", app)
    }

    private func snap(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

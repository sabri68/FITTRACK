import XCTest

/// Drives the Apple Watch app on the watchOS simulator: start, record a set, rest, finish.
final class FitTrackWatchUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func screenshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testWatchWorkoutFlow() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"]
        app.launch()

        let firstDay = app.buttons["watch.template.0"]
        XCTAssertTrue(firstDay.waitForExistence(timeout: 20), "Le programme doit être disponible sur la montre sans iPhone")
        screenshot(app, "W1-Accueil-montre")
        firstDay.tap()

        let start = app.buttons["watch.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()

        let complete = app.buttons["watch.completeSet"]
        XCTAssertTrue(complete.waitForExistence(timeout: 10))
        screenshot(app, "W2-Serie-montre")
        complete.tap()

        let skip = app.buttons["watch.skipRest"]
        XCTAssertTrue(skip.waitForExistence(timeout: 5), "Le minuteur de repos doit s'afficher")
        screenshot(app, "W3-Repos-montre")
        skip.tap()

        app.swipeRight()
        let finish = app.buttons["watch.finish"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5))
        finish.tap()

        let ok = app.buttons["watch.summaryOK"]
        XCTAssertTrue(ok.waitForExistence(timeout: 10), "Le résumé de séance doit s'afficher")
        screenshot(app, "W4-Resume-montre")
    }
}

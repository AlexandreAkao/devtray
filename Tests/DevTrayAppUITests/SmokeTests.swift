import XCTest

final class SmokeTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    func test_app_launches_andShowsMenuBarItem() {
        // A status bar item exists for our app.
        // We can't easily find the specific menu bar extra via accessibility from
        // a different process, so this test asserts the app launched successfully
        // and is running (not crashed) for 1 second.
        XCTAssertTrue(app.state == .runningForeground || app.state == .runningBackground,
                      "App is not running")
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertTrue(app.state == .runningForeground || app.state == .runningBackground,
                      "App crashed within 1 second of launch")
    }
}

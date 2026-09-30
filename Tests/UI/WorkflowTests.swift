import XCTest

final class WorkflowTests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }
  override func tearDownWithError() throws { XCUIApplication().terminate() }

  private func launch() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchEnvironment["PORTFOLIO_UI_TEST"] = UUID().uuidString
    app.launch()
    return app
  }
  private func capture(_ app: XCUIApplication, _ name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
  func testOrderAdvancePersists() {
    let app = launch()
    XCTAssertTrue(app.buttons["Advance sample order"].waitForExistence(timeout: 10))
    capture(app, "tracking")
    app.buttons["Advance sample order"].tap()
    XCTAssertTrue(app.staticTexts["Preparing"].firstMatch.waitForExistence(timeout: 5))
    app.terminate()
    app.launch()
    XCTAssertTrue(app.staticTexts["Preparing"].firstMatch.waitForExistence(timeout: 5))
    if app.buttons["Start Live Activity"].exists {
      app.buttons["Start Live Activity"].tap()
      XCTAssertTrue(app.staticTexts["Live Activity started"].waitForExistence(timeout: 5))
      app.buttons["End activity"].tap()
    }
  }
}

// User interface tests

import XCTest

class UITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
        XCUIApplication().launch()
    }

    // Simple test to make sure basic functionality works
    func testBasic() {
        let app = XCUIApplication()
        let menuBarsQuery = app.menuBars

        menuBarsQuery.children(matching: .statusItem).element.click()
        menuBarsQuery.menuItems["About"].click()
        app.buttons[XCUIIdentifierCloseWindow].click()

        menuBarsQuery.children(matching: .statusItem).element.click()
        menuBarsQuery.menuItems["Quit"].click()
        XCTAssertTrue(app.wait(for: XCUIApplication.State.notRunning, timeout: 5))
    }
}

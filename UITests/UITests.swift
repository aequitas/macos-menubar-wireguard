//
//  UITests.swift
//  UITests
//
//  Created by Johan Bloemberg on 09/12/2018.
//  Copyright © 2018 Johan Bloemberg. All rights reserved.
//

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
        XCTAssert(app.state == XCUIApplication.State.notRunning)
    }
}

//
//  WireGuardStatusbarUITests.swift
//  WireGuardStatusbarUITests
//
//  Created by Johan Bloemberg on 09/12/2018.
//  Copyright © 2018 Johan Bloemberg. All rights reserved.
//

import XCTest

class WireGuardStatusbarUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
        XCUIApplication().launch()
    }

//    override func tearDown() {
//        // Put teardown code here. This method is called after the invocation of each test method in the class.
//    }

    // Simple test to make sure about dialog exists
    func testAboutDialog() {
        let app = XCUIApplication()
        let menuBarsQuery = app.menuBars
        menuBarsQuery.children(matching: .statusItem).element.click()
        menuBarsQuery.menuItems["About"].click()
        app.buttons[XCUIIdentifierCloseWindow].click()
    }

    // Simple test to make sure the application can quit
    func testQuit() {
        let app = XCUIApplication()
        let menuBarsQuery = app.menuBars
        menuBarsQuery.children(matching: .statusItem).element.click()
        menuBarsQuery.menuItems["Quit"].click()
        XCTAssert(app.state == XCUIApplication.State.notRunning)
    }

}

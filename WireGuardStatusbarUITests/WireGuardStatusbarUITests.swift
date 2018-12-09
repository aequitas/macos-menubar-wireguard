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
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
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
        menuBarsQuery/*@START_MENU_TOKEN@*/.menuItems["About"]/*[[".statusItems",".menus.menuItems[\"About\"]",".menuItems[\"About\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.click()
        app/*@START_MENU_TOKEN@*/.buttons[XCUIIdentifierCloseWindow]/*[[".dialogs.buttons[XCUIIdentifierCloseWindow]",".buttons[XCUIIdentifierCloseWindow]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.click()
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

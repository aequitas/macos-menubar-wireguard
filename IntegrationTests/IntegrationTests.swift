//
//  IntegrationTests.swift
//  IntegrationTests
//
//  Created by Johan Bloemberg on 11/12/2018.
//  Copyright © 2018 Johan Bloemberg. All rights reserved.
//

import XCTest

class IntegrationTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
        XCUIApplication().launch()
    }

    // If configuration is loaded correctly the proper menu item should be clickable
    func testLoadConfiguration() {
        let menuBarsQuery = XCUIApplication().menuBars
        menuBarsQuery.children(matching: .statusItem).element.click()
        menuBarsQuery.menuItems["test: 192.0.2.0/32"].click()
    }
}

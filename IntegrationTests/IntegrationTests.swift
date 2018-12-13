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

        // Verify the proper configuration file for testing is installed.
        let bundle = Bundle(for: type(of: self).self)
        let testConfig = bundle.path(forResource: "test", ofType: "conf")
        if !FileManager.default.contentsEqual(atPath: testConfig!, andPath: "/etc/wireguard/test.conf") {
            XCTFail("Integration test environment not prepared. Please run `make prep-integration`.")
        }

        XCUIApplication().launch()
    }

    // If configuration is loaded correctly the proper menu item should be clickable
    func testLoadConfiguration() {
        let menuBarsQuery = XCUIApplication().menuBars
        menuBarsQuery.children(matching: .statusItem).element.click()
        menuBarsQuery.menuItems["test"].click()
    }
}

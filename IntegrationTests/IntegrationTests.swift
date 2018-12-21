// (UI) tests that interact with WireGuard runtime and configuration.

import XCTest

let testConfigFile = "test-localhost"

class IntegrationTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false

        // Verify the proper configuration file for testing is installed.
        let bundle = Bundle(for: type(of: self).self)
        let testConfig = bundle.path(forResource: testConfigFile, ofType: "conf")
        if !FileManager.default.contentsEqual(atPath: testConfig!, andPath: "/etc/wireguard/\(testConfigFile).conf") {
            XCTFail("Integration test environment not prepared. Please run `make prep-integration`.")
        }

        XCUIApplication().launch()
    }

    // If configuration is loaded correctly the proper menu item should be available
    func testLoadConfiguration() {
        let menuBarsQuery = XCUIApplication().menuBars
        menuBarsQuery.children(matching: .statusItem).element.click()
        XCTAssertTrue(menuBarsQuery.menuItems[testConfigFile].exists)
    }

    // Tunnel should be checked and show details if it is enabled
    func testEnableTunnel() {
        let menuBarsQuery = XCUIApplication().menuBars
        menuBarsQuery.children(matching: .statusItem).element.click()
        menuBarsQuery.menuItems[testConfigFile].click()

        menuBarsQuery.children(matching: .statusItem).element.click()
        // TODO discover how to verify the checked state of the menuitem, eg axMenuItemMarkChar
        XCTAssertTrue(menuBarsQuery.menuItems["  Address: 192.0.2.0/32"].exists)

        // disable tunnel after the test
        menuBarsQuery.menuItems[testConfigFile].click()
        menuBarsQuery.children(matching: .statusItem).element.click()
        XCTAssertFalse(menuBarsQuery.menuItems["  Address: 192.0.2.0/32"].exists)

    }
}

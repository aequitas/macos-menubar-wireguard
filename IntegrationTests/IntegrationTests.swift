// (UI) tests that interact with WireGuard runtime and configuration.

import XCTest

let testConfigFile = "test-localhost"
let testConfigFileInvalid = "test-invalid"
let testConfigFileUsrLocal = "test-usr-local"

class IntegrationTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false

        // Verify the proper configuration files for testing are installed.
        let bundle = Bundle(for: type(of: self).self)
        var requiredTestConfigFiles = [testConfigFile, testConfigFileInvalid].map { "/etc/wireguard/\($0).conf" }
        requiredTestConfigFiles.append("/opt/homebrew/etc/wireguard/\(testConfigFileUsrLocal).conf")
        for configFilePath in requiredTestConfigFiles {
            let configFileName = ((configFilePath as NSString).lastPathComponent as NSString).deletingPathExtension
            let testConfig = bundle.path(forResource: configFileName, ofType: "conf")
            if !FileManager.default.contentsEqual(atPath: testConfig!, andPath: configFilePath) {
                XCTFail("Integration test environment not prepared. Please run `make prep-integration`.")
            }
        }
        let app = XCUIApplication()
        app.launchEnvironment = ["RESET_CONFIGURATION": "1"]
        app.launch()

        // gives a little more time before starting a test to enter the password to install the helper
        addUIInterruptionMonitor(withDescription: "Wait for Helper install password dialog") { alert -> Bool in
            if alert.buttons["Install Helper"].exists {
                sleep(1_000_000_000)
                return true
            }
            return false
        }
    }

    // If configuration is loaded correctly the proper menu item should be available
    func testLoadConfiguration() {
        let menuBarsQuery = XCUIApplication().menuBars
        menuBarsQuery.children(matching: .statusItem).element.click()
        XCTAssertTrue(menuBarsQuery.menuItems[testConfigFile].exists)
        XCTAssertTrue(menuBarsQuery.menuItems[testConfigFileInvalid].exists)
        XCTAssertTrue(menuBarsQuery.menuItems[testConfigFileUsrLocal].exists)
    }

    // Tunnel should be checked and show details if it is enabled
    func testEnableTunnel() {
        let menuBarsQuery = XCUIApplication().menuBars
        menuBarsQuery.children(matching: .statusItem).element.click()
        menuBarsQuery.menuItems[testConfigFile].click()

        menuBarsQuery.children(matching: .statusItem).element.click()
        // TODO: discover how to verify the checked state of the menuitem, eg axMenuItemMarkChar
        XCTAssertTrue(menuBarsQuery.menuItems["Address: 192.0.2.0/32"].exists)

        // disable tunnel after the test
        menuBarsQuery.menuItems[testConfigFile].click()
        menuBarsQuery.children(matching: .statusItem).element.click()
        XCTAssertFalse(menuBarsQuery.menuItems["  Address: 192.0.2.0/32"].exists)
    }

    func testGetTunnels() {
        let bundle = Bundle(for: type(of: self).self)

        // swiftlint:disable:next force_try
        let testConfig = try! String(contentsOfFile: bundle.path(forResource: testConfigFile, ofType: "conf")!)

        Helper().getTunnels(reply: { tunnelInfo in
            // since test tunnel configuration is bogus, we never expect a connected tunnel
            XCTAssertEqual(tunnelInfo["test-localhost"]![0], "")
            XCTAssertEqual(tunnelInfo["test-localhost"]![1], WireGuard.censorConfigurationData(testConfig))
        })
    }

    // test if changing the tunnel details preference has the desired effect
    func testPreferences() {
        let app = XCUIApplication()
        let menuBarsQuery = app.menuBars
        menuBarsQuery.children(matching: .statusItem).element.click()
        // sanity check
        XCTAssertFalse(menuBarsQuery.menuItems["Address: 192.0.2.0/32"].exists)

        menuBarsQuery.menuItems["Preferences..."].click()
        let wireguardstatusbarPreferencesWindow = app.windows["WireGuardStatusbar Preferences"]
        wireguardstatusbarPreferencesWindow.checkBoxes["Show details on all tunnels"].click()
        wireguardstatusbarPreferencesWindow.buttons[XCUIIdentifierCloseWindow].click()

        menuBarsQuery.children(matching: .statusItem).element.click()
        XCTAssertTrue(menuBarsQuery.menuItems["Address: 192.0.2.0/32"].exists)
    }

    func testShowError() {
        let app = XCUIApplication()
        let notificationCenter = XCUIApplication(bundleIdentifier: "com.apple.notificationcenterui")

        let menuBarsQuery = app.menuBars
        let statusItem = menuBarsQuery.children(matching: .statusItem).element
        statusItem.click()

        let testInvalidMenuItem = menuBarsQuery.menuItems["test-invalid"]
        testInvalidMenuItem.click()

        notificationCenter.buttons["Show"].click()

        // alert should popup with error message visible
        let text = app.staticTexts.element(boundBy: 1).value as? String
        XCTAssertTrue(text?.contains("Configuration parsing error") ?? false)

        app.dialogs["alert"].buttons["OK"].click()
    }

    func testTunnelDetails() {
        let menuBarsQuery = XCUIApplication().menuBars
        XCUIElement.perform(withKeyModifiers: .option) {
            menuBarsQuery.children(matching: .statusItem).element.click()
        }

        XCTAssertTrue(menuBarsQuery.menuItems["Address: 192.0.2.0/32"].exists)
        // details for /opt/homebrew/etc/wireguard config
        XCTAssertTrue(menuBarsQuery.menuItems["Address: 192.0.3.0/32"].exists)
    }
}

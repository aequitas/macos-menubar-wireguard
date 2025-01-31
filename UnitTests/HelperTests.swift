// Helper unit tests

import XCTest

class HelperTests: XCTestCase {
    // test wg-quick is called and returns 1 as exitcode since it cannot sudo
    // TODO: mock out something or ditch test
//    func testSetTunnel() {
//        Helper().setTunnel(tunnelName: "test", enable: true, reply: { exitCode in
//            XCTAssertEqual(exitCode, 1)
//        })
//        Helper().setTunnel(tunnelName: "test", enable: false, reply: { exitCode in
//            XCTAssertEqual(exitCode, 1)
//        })
//    }

    // invalid tunnel names should not be accepted
    func testTunnelNames() {
        XCTAssertTrue(WireGuard.validateTunnelName(tunnelName: "test"))
        XCTAssertFalse(WireGuard.validateTunnelName(tunnelName: ""))
        XCTAssertFalse(WireGuard.validateTunnelName(tunnelName: ";rm -rf *"))
    }

    // a version string should be returned
    func testGetVersion() {
        Helper().getVersion { version in
            XCTAssertNotEqual(version, "n/a")
        }
    }

    // when reading configs don't expose the private keys as we currently have not mechanism
    // in place to prevent unauthorized xpc calls to the helper
    func testDontExposePrivates() {
        for (name, config) in testConfigs {
            print("Testing config \(name)")
            let censoredConfigData = WireGuard.censorConfigurationData(config)
            XCTAssertFalse(censoredConfigData.contains(testPrivateKey))
        }
    }
}

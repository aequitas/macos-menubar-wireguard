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
        XCTAssertTrue(validateTunnelName(tunnelName: "test"))
        XCTAssertFalse(validateTunnelName(tunnelName: ""))
        XCTAssertFalse(validateTunnelName(tunnelName: ";rm -rf *"))
    }

    // a version string should be returned
    func testGetVersion() {
        Helper().getVersion { version in
            XCTAssertNotEqual(version, "n/a")
        }
    }
}

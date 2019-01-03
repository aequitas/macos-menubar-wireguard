//

import XCTest

// func helperRunning() -> Bool {
// TODO: find a way (inside the XCTest sandbox) to check if WireGuardStatusbarHelper process is running.
// /bin/ps or /usr/bin/pgrep are not working inside the sandbox. /bin/launchctl only provides user owned
// processes as does runningApplications
// }
//
// class HelperTests: XCTestCase {
//    func testHelperLifecycle(){
//        XCUIApplication().launch()
//
//        // avoid race conditions a little
//        sleep(1)
//
//        // helper should be running after start of app
//        XCTAssertTrue(helperRunning())
//
//        XCUIApplication().terminate()
//
//        // <10 seconds after starting the (now closed) app the helper should still be running
//        sleep(5)
//        XCTAssertTrue(helperRunning())
//
//        // >10 seconds after starting the (now closed) app the helper should have quit
//        sleep(5)
//        XCTAssertFalse(helperRunning())
//    }
// }

//
//  UnitTests.swift
//  UnitTests
//
//  Created by Johan Bloemberg on 09/12/2018.
//  Copyright © 2018 Johan Bloemberg. All rights reserved.
//

import XCTest

class UnitTests: XCTestCase {
    // menu image should properly represent state of tunnels
    func testMenuImage() {
        var tunnels = [
            "test": Tunnel(
                name: "test",
                interface: "test",
                connected: false,
                address: "",
                peers: []
            ),
        ]
        XCTAssertEqual(menuImage(tunnels: tunnels).name(), "dragon-dim")
        tunnels["test"]!.connected = true
        XCTAssertEqual(menuImage(tunnels: tunnels).name(), "silhouette")
    }

//    func testPerformanceExample() {
//        // This is an example of a performance test case.
//        measure {
//            // Put the code you want to measure the time of here.
//        }
//    }
}

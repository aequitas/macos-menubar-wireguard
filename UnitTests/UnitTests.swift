//
//  UnitTests.swift
//  UnitTests
//
//  Created by Johan Bloemberg on 09/12/2018.
//  Copyright © 2018 Johan Bloemberg. All rights reserved.
//

import XCTest

class UnitTests: XCTestCase {
    let testTunnels = [
        "test": Tunnel(
            interface: "Tunnel Name",
            connected: false,
            address: "192.0.2.0/32",
            peers: [Peer(
                endpoint: "192.0.2.1/32:51820",
                allowedIps: ["198.51.100.0/24"]
            )]
        ),
    ]

    let testConfig = """
    # A WireGuard config used for integration testing
    [Interface]
    Address = 192.0.2.0/32
    PrivateKey = MIKtfK9lvhBbMU9xThDJ+fe7XXN009ljIKiVDxEMXn0=
    [Peer]
    PublicKey = ExO1PPLobAXSOCDFs7GpwJcG+5VMQZD9Pk73YqxXoS8=
    Endpoint = 192.0.2.1/32:51820
    AllowedIPs = 198.51.100.0/24
    """

    let testConfigDifferentCaseSection = """
    [Interface]
    Address = 10.10.101.123/24
    ListenPort = 51824
    PrivateKey = X

    [Peer]
    PublicKey = X
    Endpoint = 123.456.789.123:12345
    #AllowedIps = 0.0.0.0/0
    AllowedIps = 125.125.125.125/24, 123.123.123.123/24

    PersistentKeepalive = 25
    """

    // menu image should properly represent state of tunnels
    func testMenuImage() {
        var tunnels = testTunnels

        XCTAssertEqual(menuImage(tunnels: tunnels).name(), "dragon-dim")
        tunnels["test"]!.connected = true
        XCTAssertEqual(menuImage(tunnels: tunnels).name(), "silhouette")
    }

    func testMenu() {
        let menu = buildMenu(tunnels: testTunnels)
        XCTAssertEqual(menu.items[0].title, "Tunnel Name")
        XCTAssertEqual(menu.items[0].state, NSControl.StateValue.off)
    }

    func testMenuEnabledTunnel() {
        var tunnels = testTunnels
        tunnels["test"]!.connected = true

        let menu = buildMenu(tunnels: tunnels)
        XCTAssertEqual(menu.items[0].title, "Tunnel Name")
        XCTAssertEqual(menu.items[0].state, NSControl.StateValue.on)
        XCTAssertEqual(menu.items[1].title, "  Address: 192.0.2.0/32")
        XCTAssertEqual(menu.items[2].title, "  Endpoint: 192.0.2.1/32:51820")
        XCTAssertEqual(menu.items[3].title, "  Allowed IPs: 198.51.100.0/24")
    }

    func testMenuDetails() {
        var tunnels = testTunnels
        tunnels["test"]!.connected = true

        let menu = buildMenu(tunnels: tunnels, details: true)
        XCTAssertEqual(menu.items[0].title, "Tunnel Name")
        XCTAssertEqual(menu.items[0].state, NSControl.StateValue.on)
        XCTAssertEqual(menu.items[1].title, "  Address: 192.0.2.0/32")
        XCTAssertEqual(menu.items[2].title, "  Endpoint: 192.0.2.1/32:51820")
        XCTAssertEqual(menu.items[3].title, "  Allowed IPs: 198.51.100.0/24")
    }

    func testMenuNoTunnels() {
        let menu = buildMenu(tunnels: Tunnels())
        XCTAssertEqual(menu.items[0].title, "No tunnel configurations found")
    }

    func testMenuSorting() {
        let tunnels = [
            "Z": Tunnel(interface: "Z Tunnel Name", connected: false, address: "", peers: []),
            "A": Tunnel(interface: "A Tunnel Name", connected: false, address: "", peers: []),
        ]
        let menu = buildMenu(tunnels: tunnels)
        // tunnels should be sorted alphabetically
        XCTAssertEqual(menu.items[0].title, "A Tunnel Name")
    }

    func testConfigParsing() {
        let bundle = Bundle(for: type(of: self).self)
        let testConfigFile = bundle.path(forResource: "test", ofType: "conf")!

        if let tunnel = Tunnel(fromFile: testConfigFile) {
            XCTAssertEqual(tunnel.address, "192.0.2.0/32")
            XCTAssertEqual(tunnel.peers[0].endpoint, "192.0.2.1/32:51820")
            XCTAssertEqual(tunnel.peers[0].allowedIps, ["198.51.100.0/24"])
        } else {
            XCTFail("Config file not parsed")
        }
    }

    func testConfigParsing2() {
        let bundle = Bundle(for: type(of: self).self)
        let testConfigFile = bundle.path(forResource: "different-case-section", ofType: "conf")!

        if let tunnel = Tunnel(fromFile: testConfigFile) {
            XCTAssertEqual(tunnel.address, "10.10.101.123/24")
        } else {
            XCTFail("Config file not parsed")
        }
    }

//    func testPerformanceExample() {
//        // This is an example of a performance test case.
//        measure {
//            // Put the code you want to measure the time of here.
//        }
//    }
}

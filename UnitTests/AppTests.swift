// Application unit tests

import XCTest

class AppTests: XCTestCase {
    let testTunnels: [Tunnel] = [
        Tunnel(
            name: "1 Tunnel Name",
            config: TunnelConfig(
                address: "192.0.2.0/32",
                peers: [Peer(
                    endpoint: "192.0.2.1/32:51820",
                    allowedIps: ["198.51.100.0/24"]
                )]
            )
        ),
        Tunnel(name: "2 Invalid Config", config: nil),
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

        XCTAssertEqual(menuImage(tunnels: tunnels).name(), "dragon")
        tunnels[0].interface = "utun1"
        XCTAssertEqual(menuImage(tunnels: tunnels).name(), "silhouette")
    }

    func testMenu() {
        let menu = buildMenu(tunnels: testTunnels)
        XCTAssertEqual(menu.items[0].title, "1 Tunnel Name")
        XCTAssertEqual(menu.items[0].state, NSControl.StateValue.off)
    }

    func testMenuEnabledTunnel() {
        var tunnels = testTunnels
        tunnels[0].interface = "utun1"

        let menu = buildMenu(tunnels: tunnels)
        XCTAssertEqual(menu.items[0].title, "1 Tunnel Name")
        XCTAssertEqual(menu.items[0].state, NSControl.StateValue.on)
        XCTAssertEqual(menu.items[1].title, "  Interface: utun1")
        XCTAssertEqual(menu.items[2].title, "  Address: 192.0.2.0/32")
        XCTAssertEqual(menu.items[3].title, "  Endpoint: 192.0.2.1/32:51820")
        XCTAssertEqual(menu.items[4].title, "  Allowed IPs: 198.51.100.0/24")
    }

    func testMenuEnabledTunnelNoDetails() {
        var tunnels = testTunnels
        tunnels[0].interface = "utun1"

        let menu = buildMenu(tunnels: tunnels, connectedTunnelDetails: false)
        XCTAssertEqual(menu.items[1].title, "2 Invalid Config")
    }

    func testMenuDetails() {
        var tunnels = testTunnels
        tunnels[0].interface = "utun1"

        let menu = buildMenu(tunnels: tunnels, allTunnelDetails: true)
        XCTAssertEqual(menu.items[0].title, "1 Tunnel Name")
        XCTAssertEqual(menu.items[0].state, NSControl.StateValue.on)
        XCTAssertEqual(menu.items[1].title, "  Interface: utun1")
        XCTAssertEqual(menu.items[2].title, "  Address: 192.0.2.0/32")
        XCTAssertEqual(menu.items[3].title, "  Endpoint: 192.0.2.1/32:51820")
        XCTAssertEqual(menu.items[4].title, "  Allowed IPs: 198.51.100.0/24")
    }

    func testMenuDetailsInvalidConfig() {
        var tunnels = testTunnels
        tunnels[1].interface = "utun1"

        let menu = buildMenu(tunnels: tunnels, allTunnelDetails: true)
        let offset = 4
        XCTAssertEqual(menu.items[0 + offset].title, "2 Invalid Config")
        XCTAssertEqual(menu.items[0 + offset].state, NSControl.StateValue.on)
        XCTAssertEqual(menu.items[1 + offset].title, "  Interface: utun1")
        XCTAssertEqual(menu.items[2 + offset].title, "  Could not parse tunnel configuration!")
    }

    func testMenuNoTunnels() {
        let menu = buildMenu(tunnels: Tunnels())
        XCTAssertEqual(menu.items[0].title, "No tunnel configurations found")
    }

    func testMenuSorting() {
        let tunnels: [Tunnel] = [
            Tunnel(name: "Z Tunnel Name"),
            Tunnel(name: "A Tunnel Name"),
        ]
        let menu = buildMenu(tunnels: tunnels)
        // tunnels should be sorted alphabetically
        XCTAssertEqual(menu.items[0].title, "A Tunnel Name")
    }

    func testConfigParsing() {
        if let config = TunnelConfig(fromConfig: testConfig) {
            XCTAssertEqual(config.address, "192.0.2.0/32")
            XCTAssertEqual(config.peers[0].endpoint, "192.0.2.1/32:51820")
            XCTAssertEqual(config.peers[0].allowedIps, ["198.51.100.0/24"])
        } else {
            XCTFail("Config file not parsed")
        }
    }

    func testConfigParsing2() {
        if let config = TunnelConfig(fromConfig: testConfigDifferentCaseSection) {
            XCTAssertEqual(config.address, "10.10.101.123/24")
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

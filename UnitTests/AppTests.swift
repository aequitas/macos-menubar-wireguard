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

    // menu image should properly represent state of tunnels
    func testMenuImage() {
        var tunnels = testTunnels

        XCTAssertEqual(menuImage(tunnels: tunnels).name(), "dragon")
        tunnels[0].interface = "utun1"
        XCTAssertEqual(menuImage(tunnels: tunnels).name(), "silhouette")
    }

    func testMenu() {
        let items = buildMenu(tunnels: testTunnels)
        XCTAssertEqual(items[0].title, "1 Tunnel Name")
        XCTAssertEqual(items[0].state, NSControl.StateValue.off)
    }

    func testMenuEnabledTunnel() {
        var tunnels = testTunnels
        tunnels[0].interface = "utun1"

        let items = buildMenu(tunnels: tunnels)
        XCTAssertEqual(items[0].title, "1 Tunnel Name")
        XCTAssertEqual(items[0].state, NSControl.StateValue.on)
        XCTAssertEqual(items[1].title, "Interface: utun1")
        XCTAssertEqual(items[2].title, "Address: 192.0.2.0/32")
        XCTAssertEqual(items[3].title, "Endpoint: 192.0.2.1/32:51820")
        XCTAssertEqual(items[4].title, "Allowed IPs: 198.51.100.0/24")
    }

    func testMenuEnabledTunnelNoDetails() {
        var tunnels = testTunnels
        tunnels[0].interface = "utun1"

        let items = buildMenu(tunnels: tunnels, connectedTunnelDetails: false)
        XCTAssertEqual(items[1].title, "2 Invalid Config")
    }

    func testMenuDetails() {
        var tunnels = testTunnels
        tunnels[0].interface = "utun1"

        let items = buildMenu(tunnels: tunnels, allTunnelDetails: true)
        XCTAssertEqual(items[0].title, "1 Tunnel Name")
        XCTAssertEqual(items[0].state, NSControl.StateValue.on)
        XCTAssertEqual(items[1].title, "Interface: utun1")
        XCTAssertEqual(items[1].indentationLevel, 1)
        XCTAssertEqual(items[2].title, "Address: 192.0.2.0/32")
        XCTAssertEqual(items[2].indentationLevel, 1)
        XCTAssertEqual(items[3].title, "Endpoint: 192.0.2.1/32:51820")
        XCTAssertEqual(items[3].indentationLevel, 1)
        XCTAssertEqual(items[4].title, "Allowed IPs: 198.51.100.0/24")
        XCTAssertEqual(items[4].indentationLevel, 1)
    }

    func testMenuDetailsInvalidConfig() {
        var tunnels = testTunnels
        tunnels[1].interface = "utun1"

        let items = buildMenu(tunnels: tunnels, allTunnelDetails: true)
        let offset = 4
        XCTAssertEqual(items[0 + offset].title, "2 Invalid Config")
        XCTAssertEqual(items[0 + offset].state, NSControl.StateValue.on)
        XCTAssertEqual(items[1 + offset].title, "Interface: utun1")
        XCTAssertEqual(items[2 + offset].title, "Could not parse tunnel configuration!")
    }

    func testMenuNoTunnels() {
        let items = buildMenu(tunnels: Tunnels())
        XCTAssertEqual(items[0].title, "No tunnel configurations found")
    }

    func testMenuSorting() {
        let tunnels: [Tunnel] = [
            Tunnel(name: "Z Tunnel Name"),
            Tunnel(name: "A Tunnel Name"),
        ]
        let items = buildMenu(tunnels: tunnels)
        // tunnels should be sorted alphabetically
        XCTAssertEqual(items[0].title, "A Tunnel Name")
    }

    func testConfigParsing() {
        for (name, config) in testConfigs {
            print("Testing config \(name)")
            if let config = TunnelConfig(fromConfig: config) {
                XCTAssertEqual(config.address, "192.0.2.0/32")
                XCTAssertEqual(config.peers[0].endpoint, "192.0.2.1/32:51820")
                XCTAssertEqual(config.peers[0].allowedIps, ["198.51.100.0/24"])
            } else {
                XCTFail("Config file not parsed")
            }
        }
    }
}

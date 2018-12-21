// Menu building

import Cocoa

// contruct menu with all tunnels found in configuration
// TODO: find out if it is possible to have a dynamic bound IB menu with variable contents
func buildMenu(tunnels: Tunnels, details: Bool = false, showInstallInstructions: Bool = false) -> NSMenu {
    // TODO: currently just rebuilding the entire menu, maybe opt for replacing the tunnel entries instead?
    let statusMenu = NSMenu()
    statusMenu.minimumWidth = 200

    statusMenu.addItem(NSMenuItem.separator())
    statusMenu.addItem(NSMenuItem(title: "About", action: #selector(AppDelegate.about(_:)), keyEquivalent: ""))
    statusMenu.addItem(NSMenuItem(title: "Quit", action: #selector(AppDelegate.quit(_:)), keyEquivalent: "q"))

    // WireGaurd missing is a big problem, user should fix this first. TODO, include WireGuard with the App
    if showInstallInstructions {
        NSLog("WireGuard binary not found at \(wireguardBin)")
        statusMenu.insertItem(NSMenuItem(title: "WireGuard not installed! Click here for instructions",
                                         action: #selector(AppDelegate.showInstallInstructions(_:)),
                                         keyEquivalent: ""), at: 0)
        return statusMenu
    }

    if tunnels.isEmpty {
        statusMenu.insertItem(NSMenuItem(title: "No tunnel configurations found",
                                         action: nil, keyEquivalent: ""), at: 0)
    } else {
        for (tunnelName, tunnel) in tunnels.sorted(by: { $0.0 > $1.0 }) {
            let item = NSMenuItem(title: "\(tunnelName)",
                                  action: #selector(AppDelegate.toggleTunnel(_:)), keyEquivalent: "")
            item.representedObject = tunnelName
            if tunnel.connected {
                item.state = NSControl.StateValue.on
            }
            if tunnel.connected || details, let config = tunnel.config {
                for peer in config.peers {
                    statusMenu.insertItem(NSMenuItem(title: "  Allowed IPs: \(peer.allowedIps.joined(separator: ", "))",
                                                     action: nil, keyEquivalent: ""), at: 0)
                    statusMenu.insertItem(NSMenuItem(title: "  Endpoint: \(peer.endpoint)",
                                                     action: nil, keyEquivalent: ""), at: 0)
                }
                statusMenu.insertItem(NSMenuItem(title: "  Address: \(config.address)",
                                                 action: nil, keyEquivalent: ""), at: 0)
            }
            statusMenu.insertItem(item, at: 0)
        }
    }

    return statusMenu
}

func menuImage(tunnels: Tunnels) -> NSImage {
    let connectedTunnels = tunnels.filter { $1.connected }
    if connectedTunnels.isEmpty {
        let icon = NSImage(named: .disabled)!
        icon.isTemplate = true
        return icon
    } else {
        let icon = NSImage(named: .connected)!
        icon.isTemplate = true
        return icon
    }
}

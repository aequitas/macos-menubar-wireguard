// Menu building

import Cocoa

// contruct menu with all tunnels found in configuration
// TODO: find out if it is possible to have a dynamic bound IB menu with variable contents
func buildMenu(tunnels: Tunnels, allTunnelDetails: Bool = false, connectedTunnelDetails: Bool = true,
               showInstallInstructions: Bool = false) -> NSMenu {
    // TODO: currently just rebuilding the entire menu, maybe opt for replacing the tunnel entries instead?
    let statusMenu = NSMenu()
    statusMenu.minimumWidth = 200

    statusMenu.addItem(NSMenuItem.separator())
    statusMenu.addItem(NSMenuItem(title: "About", action: #selector(AppDelegate.about(_:)),
                                  keyEquivalent: ""))
    statusMenu.addItem(NSMenuItem(title: "Preferences...", action: #selector(AppDelegate.preferences(_:)),
                                  keyEquivalent: ","))
    statusMenu.addItem(NSMenuItem(title: "Quit", action: #selector(AppDelegate.quit(_:)),
                                  keyEquivalent: "q"))

    // WireGaurd missing is a big problem, user should fix this first. TODO, include WireGuard with the App
    if showInstallInstructions {
        NSLog("WireGuard binary was not found at '\(wireguardBinPath)'")
        statusMenu.insertItem(NSMenuItem(title: "WireGuard not installed! Click here for instructions...",
                                         action: #selector(AppDelegate.showInstallInstructions(_:)),
                                         keyEquivalent: ""), at: 0)
        statusMenu.insertItem(NSMenuItem.separator(), at: 0)
    }

    if tunnels.isEmpty {
        statusMenu.insertItem(NSMenuItem(title: "No tunnel configurations found",
                                         action: nil, keyEquivalent: ""), at: 0)
    } else {
        for tunnel in tunnels.sorted(by: { $0.name.lowercased() > $1.name.lowercased() }) {
            let item = NSMenuItem(title: "\(tunnel.name)",
                                  action: #selector(AppDelegate.toggleTunnel(_:)), keyEquivalent: "")
            item.representedObject = tunnel.name
            if tunnel.connected {
                item.state = NSControl.StateValue.on
            }
            if (tunnel.connected && connectedTunnelDetails) || allTunnelDetails {
                if let config = tunnel.config {
                    for peer in config.peers {
                        statusMenu.insertItem(
                            NSMenuItem(title: "  Allowed IPs: \(peer.allowedIps.joined(separator: ", "))",
                                       action: nil, keyEquivalent: ""), at: 0
                        )
                        statusMenu.insertItem(NSMenuItem(title: "  Endpoint: \(peer.endpoint)",
                                                         action: nil, keyEquivalent: ""), at: 0)
                    }
                    statusMenu.insertItem(NSMenuItem(title: "  Address: \(config.address)",
                                                     action: nil, keyEquivalent: ""), at: 0)
                } else {
                    statusMenu.insertItem(NSMenuItem(title: "  Could not parse tunnel configuration!",
                                                     action: nil, keyEquivalent: ""), at: 0)
                }
            }

            if tunnel.connected && (connectedTunnelDetails || allTunnelDetails), let interface = tunnel.interface {
                statusMenu.insertItem(NSMenuItem(title: "  Interface: \(interface)",
                                                 action: nil, keyEquivalent: ""), at: 0)
            }

            statusMenu.insertItem(item, at: 0)
        }
    }

    return statusMenu
}

func menuImage(tunnels: Tunnels) -> NSImage {
    let connectedTunnels = tunnels.filter { $0.connected }
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

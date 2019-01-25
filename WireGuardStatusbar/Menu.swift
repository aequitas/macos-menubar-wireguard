// Menu building

import Cocoa

enum MenuItemTypes: Int {
    case none = 0, tunnel, tunnelplaceholder
}

class TunnelDetailMenuItem: NSMenuItem {
    override var indentationLevel: Int {
        get { return 1 }
        set { self.indentationLevel = newValue }
    }
}

let maxMenuItemChars = 40

extension String {
    enum TruncationPosition {
        case head
        case middle
        case tail
    }

    func truncated(limit: Int, position: TruncationPosition = .tail, leader: String = "...") -> String {
        guard count > limit else { return self }

        switch position {
        case .head:
            return leader + suffix(limit)
        case .middle:
            let headCharactersCount = Int(ceil(Float(limit - leader.count) / 2.0))

            let tailCharactersCount = Int(floor(Float(limit - leader.count) / 2.0))

            return "\(prefix(headCharactersCount))\(leader)\(suffix(tailCharactersCount))"
        case .tail:
            return prefix(limit) + leader
        }
    }
}

// contruct menu with all tunnels found in configuration
// TODO: find out if it is possible to have a dynamic bound IB menu with variable contents
func buildMenu(tunnels: Tunnels,
               allTunnelDetails: Bool = false,
               connectedTunnelDetails: Bool = true,
               showInstallInstructions _: Bool = false) -> [NSMenuItem] {
    guard !tunnels.isEmpty else {
        return [NSMenuItem(title: "No tunnel configurations found",
                           action: nil, keyEquivalent: "")]
    }

    var items: [NSMenuItem] = []
    for tunnel in tunnels.sorted(by: { $0.name.lowercased() < $1.name.lowercased() }) {
        let item = NSMenuItem(title: "\(tunnel.name)",
                              action: #selector(AppDelegate.toggleTunnel(_:)), keyEquivalent: "")
        items.append(item)
        item.representedObject = tunnel.name
        if tunnel.connected {
            item.state = NSControl.StateValue.on
        }

        if tunnel.connected && (connectedTunnelDetails || allTunnelDetails), let interface = tunnel.interface {
            items.append(TunnelDetailMenuItem(title: "Interface: \(interface)",
                                              action: nil, keyEquivalent: ""))
        }

        if (tunnel.connected && connectedTunnelDetails) || allTunnelDetails {
            if let config = tunnel.config {
                items.append(TunnelDetailMenuItem(title: "Address: \(config.address)",
                                                  action: nil, keyEquivalent: ""))
                for peer in config.peers {
                    let endpointTitle = "Endpoint: \(peer.endpoint)"
                    let endpointItem = TunnelDetailMenuItem(title: endpointTitle.truncated(limit: maxMenuItemChars,
                                                                                           position: .middle),
                                                            action: nil, keyEquivalent: "")
                    endpointItem.toolTip = endpointTitle
                    items.append(endpointItem)

                    let ipsTitle = "Allowed IPs: \(peer.allowedIps.joined(separator: ", "))"
                    let ipsItem = TunnelDetailMenuItem(title: ipsTitle.truncated(limit: maxMenuItemChars,
                                                                                 position: .middle),
                                                       action: nil, keyEquivalent: "")
                    ipsItem.toolTip = ipsTitle
                    items.append(ipsItem)
                }
            } else {
                items.append(TunnelDetailMenuItem(title: "Could not parse tunnel configuration!",
                                                  action: nil, keyEquivalent: ""))
            }
        }
    }

    return items
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

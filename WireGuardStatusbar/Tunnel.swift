// Tunnel config/state logic

import Foundation

// List of all tunnels known by this application, used to build menu
// Tunnels are referenced by their configuration file name similar to how wg-quick would.
typealias Tunnels = [Tunnel]

struct Tunnel {
    let name: String

    // name of the interface associated with this tunnel (if connected)
    var interface: TunnelInterface?

    // tunnel configuration read from configuration file or `wg showconf`
    var config: TunnelConfig?

    // TODO: var stats: TunnelStats?

    var connected: Bool { return interface != nil }
}

struct TunnelConfig {
    var address = ""
    var peers: [Peer] = []
}

struct Peer {
    var endpoint: String
    var allowedIps: [String]
}

extension Tunnel {
    init(name: String, config: TunnelConfig? = nil) {
        self.name = name
        self.config = config
    }

    init(name: String, fromTunnelInfo tunnelInfo: [TunnelInterfaceOrConfigData]) {
        self.name = name
        interface = tunnelInfo[0] != "" ? tunnelInfo[0] : nil
        config = TunnelConfig(fromConfig: tunnelInfo[1])
        if config == nil {
            NSLog("Failed to read configuration file for tunnel '\(name)'")
        }
    }
}

extension Dictionary where Key == String {
    subscript(caseInsensitive key: Key) -> Value? {
        get {
            if let key = keys.first(where: { $0.caseInsensitiveCompare(key) == .orderedSame }) {
                return self[key]
            }
            return nil
        }
        set {
            if let key = keys.first(where: { $0.caseInsensitiveCompare(key) == .orderedSame }) {
                self[key] = newValue
            } else {
                self[key] = newValue
            }
        }
    }
}

extension TunnelConfig {
    init?(fromConfig configFile: String) {
        // determine if config file can be read
        if let ini = try? INIParser(text: configFile) {
            let config = ini.sections
            if !config.isEmpty {
                // TODO: currently supports only one peer, need to pick a different method for parsing config
                let peer = config[caseInsensitive: "Peer"] ?? [:]
                peers = [Peer(
                    endpoint: peer[caseInsensitive: "Endpoint"] ?? "",
                    allowedIps: (peer[caseInsensitive: "AllowedIPs"] ?? "").split(separator: ",").map {
                        $0.trimmingCharacters(in: .whitespaces)
                    }
                )]
                let interface = config[caseInsensitive: "Interface"] ?? [:]
                address = interface[caseInsensitive: "Address"] ?? ""
            }
        } else {
            return nil
        }
    }
}

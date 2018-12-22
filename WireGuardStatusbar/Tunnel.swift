// Tunnel config/state logic

import Foundation

// List of all tunnels known by this application, used to build menu
// Tunnels are referenced by their configuration file name similar to how wg-quick would∫
typealias Tunnels = [TunnelName: Tunnel]

struct Tunnel {
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
    init(config: TunnelConfig?) {
        self.config = config
    }

    init(fromTunnelInfo tunnelInfo: [TunnelInterfaceOrConfigData]) {
        interface = tunnelInfo[0] != "" ? tunnelInfo[0] : nil
        config = TunnelConfig(fromConfig: tunnelInfo[1])
    }
}

extension TunnelConfig {
    init?(fromConfig configFile: String) {
        // determine if config file can be read
        if let ini = try? INIParser(text: configFile) {
            let config = ini.sections
            if !config.isEmpty {
                // TODO: currently supports only one peer, need to pick a different method for parsing config
                let peer = config["Peer"] ?? [:]
                peers = [Peer(
                    endpoint: peer["Endpoint"] ?? "",
                    allowedIps: (peer["AllowedIPs"] ?? "").split(separator: ",").map {
                        $0.trimmingCharacters(in: .whitespaces)
                    }
                )]
                let interface = config["Interface"] ?? [:]
                address = interface["Address"] ?? ""
            }
        } else {
            NSLog("Failed to read configuration file")
            return nil
        }
    }
}

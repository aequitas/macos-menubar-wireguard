// Constants

import Foundation

let runPath = "/var/run/wireguard"

let installInstructions = """
Currently this application does not come with WireGuard binaries. \
It is required to manually install these using Homebrew.

Please follow the instructions on:

  https://www.wireguard.com/install/

and restart this application afterwards.
"""

let defaultBrewPrefix = "/usr/local"

struct DefaultSettings {
    static let App = [
        "showAllTunnelDetails": false,
        "showConnectedTunnelDetails": true,
    ]
    static let Helper = [
        // Prefix path for etc/wireguard, bin/wg, bin/wireguard-go and bin/bash (bash 4),
        // can be overridden by the user via root defaults to allow custom location for Homebrew.
        "brewPrefix": defaultBrewPrefix,
        "wgquickBinPath": "",
    ]
}

// locations where wg-quick searches for configuration files
let configPaths = [
    "/etc/wireguard",
    "\(defaultBrewPrefix)/etc/wireguard",
]

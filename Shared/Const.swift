// Constants

import Foundation

let defaultBrewPrefix = "/usr/local"
let runPath = "/var/run/wireguard"

let wireguardBinPath = "\(defaultBrewPrefix)/bin/wg"

let installInstructions = """
Currently this Application does not come with WireGuard binaries. \
It is required to manually install these using Homebrew.

Please follow the instructions on:

  https://www.wireguard.com/install/

and restart this Application afterwards.
"""

let defaultSettings = [
    "showAllTunnelDetails": false,
    "showConnectedTunnelDetails": true,
]

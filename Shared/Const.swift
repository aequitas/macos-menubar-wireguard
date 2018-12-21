// Constants

import Foundation

let brewPrefix = "/usr/local"
let runPath = "/var/run/wireguard"

// paths to search for tunnel configurations, ordered by wg-quick's preferences
let configPaths = [
    "/etc/wireguard",
    "\(brewPrefix)/etc/wireguard",
]

let wireguardBin = "\(brewPrefix)/bin/wg"
let wgquickBin = "\(brewPrefix)/bin/wg-quick"

let installInstructions = """
Currently this Application does not come with WireGuard binaries. \
It is required to manually install these using Homebrew.

Please follow the instructions on:

  https://www.wireguard.com/install/

and restart this Application afterwards.
"""

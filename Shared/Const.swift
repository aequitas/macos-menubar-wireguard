//
//  File.swift
//  WireGuardStatusbar
//
//  Created by Johan Bloemberg on 12/08/2018.
//  Copyright © 2018 Johan Bloemberg. All rights reserved.
//

import Foundation

let brewPrefix = "/usr/local"
let runPath = "/var/run/wireguard"
let configPaths = [
    "\(brewPrefix)/etc/wireguard",
    "/etc/wireguard",
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

// make logging in debug more compact (no timestamp/process name/pid)
#if DEBUG
let NSLog = CustomLog
public func CustomLog(_ format: String, _ args: CVarArg...) {
    withVaList(args) { print(NSString(format: format, arguments: $0)) }
}
#endif

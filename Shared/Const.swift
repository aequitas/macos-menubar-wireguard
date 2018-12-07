//
//  File.swift
//  WireGuardStatusbar
//
//  Created by Johan Bloemberg on 12/08/2018.
//  Copyright © 2018 Johan Bloemberg. All rights reserved.
//

import Foundation

let brew_prefix = "/usr/local"
let run_path = "/var/run/wireguard/"
let config_paths = [
    "\(brew_prefix)/etc/wireguard",
    "/etc/wireguard",
]
let wireguard_bin = "\(brew_prefix)/bin/wg"
let wgquick_bin = "\(brew_prefix)/bin/wg-quick"

let install_instructions = """
Currently this Application does not come with WireGuard binaries. It is required to manually install these using Homebrew.

Please follow the instructions on:

  https://www.wireguard.com/install/

and restart this Application afterwards.
"""

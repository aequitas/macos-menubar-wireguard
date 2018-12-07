//
//  AppDelegate.swift
//  WireGuardStatusbar
//
//  Created by Johan Bloemberg on 10/08/2018.
//  Copyright © 2018 Johan Bloemberg. All rights reserved.
//

import Cocoa

let run_path = "/var/run/wireguard/"

extension NSImage.Name {
    static let connected = "connected"
    static let disconnected = "disconnected"
}

typealias Tunnels = [String: Tunnel]
struct Tunnel {
    var title: String { return name}
    var name: String
    var interface: String
    var connected = false
    var address: String
    var peers: [Peer]
}
struct Peer {
    var endpoint: String
    var allowedIps: [String]
}


var username = NSUserName()
let config_paths = [
    "\(brew_prefix)/etc/wireguard",
    "/etc/wireguard",
]

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, SKQueueDelegate {

    var tunnels = Tunnels()
    @objc dynamic var connected = false

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let statusMenu = NSMenu()

    let privileged_helper = PrivilegedHelper()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // initialize menu bar
        let icon = NSImage(named: .disconnected)
        icon!.isTemplate = true
        statusItem.image = icon
        statusItem.menu = statusMenu
        
        // Check if the application can connect to the helper, or if the helper has to be updated with a newer version.
        // If the helper should be updated or installed, prompt the user to do so
        privileged_helper.helperStatus {
            installed in
            if !installed {
                self.privileged_helper.installHelper()
                self.privileged_helper.xpcHelperConnection = nil  //  Nulls the connection to force a reconnection
            }
        }

        // register watchers to respond to changes in wireguard config/runtime state
        let queue = SKQueue(delegate: self)!
        queue.addPath(run_path)
        for config_path in config_paths {
            queue.addPath(config_path)
        }

        // do an initial state update from current configuration and runtime state
        DispatchQueue.global(qos: .background).async {
            self.loadConfiguration()
            self.loadState()
            DispatchQueue.main.async {self.buildMenu()}
        }
    }

//    func applicationWillTerminate(_ aNotification: Notification) {
//        TODO: disconnect and cleanup wireguard connections
//    }

    // handle incoming file/directory change events
    func receivedNotification(_ notification: SKQueueNotification, path: String, queue: SKQueue) {
        print("\(notification.toStrings().map { $0.rawValue }) @ \(path)")
        if path == run_path {
            loadState()
            DispatchQueue.main.async {self.buildMenu()}
        }
    }

    // bring tunnel up/down
    @objc func toggleTunnel(_ sender: NSMenuItem) {
        let id = sender.representedObject as! String
        let tunnel = tunnels[id]!

        let xpcService = privileged_helper.helperConnection()?.remoteObjectProxyWithErrorHandler() { error -> Void in
            print("XPCService error: %@", error)
        } as? HelperProtocol

        if !tunnel.connected {
            xpcService?.tunnelUp(interface: tunnel.interface, reply: {
                (exitStatus) in print("Tunnel \(id) up exit status: \(exitStatus)")
            })

        } else {
            xpcService?.tunnelDown(interface: tunnel.interface, reply: {
                (exitStatus) in print("Tunnel \(id) down exit status: \(exitStatus)")
            })
        }
    }

    // contruct menu with all tunnels found in configuration
    // TODO: find out if it is possible to have a dynamic bound IB menu with variable contents
    func buildMenu() {
        // TODO: currently just rebuilding the entire menu, maybe opt for replacing the tunnel entries instead?
        statusMenu.removeAllItems()

        statusMenu.addItem(NSMenuItem(title: "About", action: #selector(AppDelegate.about(_:)), keyEquivalent: ""))
        statusMenu.addItem(NSMenuItem.separator())

        var connected = false
        if tunnels.isEmpty {
            statusMenu.addItem(NSMenuItem(title: "No tunnel configurations found", action: nil, keyEquivalent: ""))
        } else {
            for (id, tunnel) in tunnels.sorted(by: { $0.0 < $1.0 }) {
                let item = NSMenuItem(title: "\(tunnel.interface): \(tunnel.address)", action: #selector(AppDelegate.toggleTunnel(_:)), keyEquivalent: "")
                item.representedObject = id
                if tunnel.connected {
                    item.state = NSControl.StateValue.on
                    connected = true
                }
                statusMenu.addItem(item)
                for peer in tunnel.peers {
                    statusMenu.addItem(NSMenuItem(title: "  \(peer.endpoint): \(peer.allowedIps.joined(separator: ", "))", action: nil, keyEquivalent: ""))
                }
            }
        }
        statusMenu.addItem(NSMenuItem.separator())
//        statusMenu.addItem(NSMenuItem(title: "Preferences...", action: #selector(AppDelegate.preferences(_:)), keyEquivalent: ","))
        statusMenu.addItem(NSMenuItem(title: "Quit", action: #selector(AppDelegate.quit(_:)), keyEquivalent: "q"))

        // TODO: find better way to do this, computed property or something?
        if connected {
            let icon = NSImage(named: .connected)
            icon!.isTemplate = true
            statusItem.image = icon
        } else {
            let icon = NSImage(named: .disconnected)
            icon!.isTemplate = true
            statusItem.image = icon
        }
    }

    // load tunnel from configuration files
    func loadConfiguration() {
        for config_path in config_paths {
            let enumerator = FileManager.default.enumerator(atPath: config_path)
            if enumerator == nil {
                continue
            }
            let files = enumerator?.allObjects as! [String]
            let config_files = files.filter{$0.hasSuffix(".conf")}
            for config_file in config_files {
                let interface = config_file.replacingOccurrences(of: ".conf", with: "")


                // determine if config file can be read
                if let _ = try? String(contentsOfFile: config_path + "/" + config_file) {
                    var config = parseConfig(config_path + "/" + config_file)

                    // TODO: currently supports only one peer, need to pick a different method for parsing config
                    let peers = [Peer(
                        endpoint: config["Peer"]!["Endpoint"]!,
                        allowedIps: config["Peer"]!["AllowedIPs"]!.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                        )
                    ]
                    let tunnel = Tunnel(
                        name: "",
                        interface: interface,
                        connected: false,
                        address: config["Interface"]!["Address"]!,
                        peers: peers
                    )
                    tunnels[interface] = tunnel
                } else {
                    // could not read config, provide minimal details
                    tunnels[interface] = Tunnel(
                        name: "",
                        interface: interface,
                        connected: false,
                        address: "",
                        peers: []
                    )
                }
            }
        }
    }

    // read runtime state of wg and update local state accordingly
    func loadState() {
        // for every configured tunnel check if a socket file exists (assume that indicates the tunnel is up)
        for tunnel in tunnels {
            let interface_name = tunnel.key
            // TODO: more idiomatic path building?
            let name = URL(string: "\(run_path)/\(interface_name).name")
            tunnels[interface_name]!.connected = FileManager.default.fileExists(atPath: name!.path)
        }
    }

// TODO: implement WireGuard settings as prefpane?
//    @objc func preferences(_ sender: NSMenuItem)
//    {
//        NSWorkspace.shared.open(NSURL(fileURLWithPath: "/System/Library/PreferencePanes/Network.prefPane") as URL)
//    }

    @objc func quit(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(self)
    }

    @objc func about(_ sender: NSMenuItem)
    {
        NSApplication.shared.orderFrontStandardAboutPanel(self)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

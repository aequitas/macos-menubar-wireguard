//
//  AppDelegate.swift
//  WireGuardStatusbar
//
//  Created by Johan Bloemberg on 10/08/2018.
//  Copyright © 2018 Johan Bloemberg. All rights reserved.
//

import Cocoa

extension NSImage.Name {
    static let connected = "silhouette"
    static let enabled = "silhouette-dim"
    static let disabled = "dragon-dim"
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

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, SKQueueDelegate {

    var tunnels = Tunnels()
    @objc dynamic var connected = false

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let statusMenu = NSMenu()

    let privilegedHelper = PrivilegedHelper()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // initialize menu bar
        let icon = NSImage(named: .disabled)
        icon!.isTemplate = true
        statusItem.image = icon
        statusItem.menu = statusMenu

        // Check if the application can connect to the helper, or if the helper has to be updated with a newer version.
        // If the helper should be updated or installed, prompt the user to do so
        privilegedHelper.helperStatus {installed in
            if !installed {
                self.privilegedHelper.installHelper()
                self.privilegedHelper.xpcHelperConnection = nil  //  Nulls the connection to force a reconnection
            }
        }

        // register watchers to respond to changes in wireguard config/runtime state
        let queue = SKQueue(delegate: self)!
        queue.addPath(runPath)
        for configPath in configPaths {
            queue.addPath(configPath)
        }

        // do an initial state update from current configuration and runtime state
        DispatchQueue.global(qos: .background).async {
            self.loadConfiguration()
            self.loadState()
            DispatchQueue.main.async {self.buildMenu()}
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
//        TODO: configurable option to disable tunnels on shutdown
        let xpcService = privilegedHelper.helperConnection()?.remoteObjectProxyWithErrorHandler { error -> Void in
            print("XPCService error: %@", error)
            } as? HelperProtocol

        xpcService?.shutdown()
    }

    // handle incoming file/directory change events
    func receivedNotification(_ notification: SKQueueNotification, path: String, queue: SKQueue) {
        print("\(notification.toStrings().map { $0.rawValue }) @ \(path)")
        if path == runPath {
            loadState()
            DispatchQueue.main.async {self.buildMenu()}
        }
    }

    // bring tunnel up/down
    @objc func toggleTunnel(_ sender: NSMenuItem) {
        if let tunnelId = sender.representedObject as? String {
            let tunnel = tunnels[tunnelId]!

            let xpcService = privilegedHelper.helperConnection()?.remoteObjectProxyWithErrorHandler { error -> Void in
                print("XPCService error: %@", error)
            } as? HelperProtocol

            if !tunnel.connected {
                xpcService?.tunnelUp(interface: tunnel.interface, reply: {(exitStatus) in
                    print("Tunnel \(tunnelId) up exit status: \(exitStatus)")
                })

            } else {
                xpcService?.tunnelDown(interface: tunnel.interface, reply: {(exitStatus) in
                    print("Tunnel \(tunnelId) down exit status: \(exitStatus)")
                })
            }
        } else {
            NSLog("Sender not convertable to String: \(sender.representedObject.debugDescription)")
        }
    }

    // contruct menu with all tunnels found in configuration
    // TODO: find out if it is possible to have a dynamic bound IB menu with variable contents
    func buildMenu() {
        // TODO: currently just rebuilding the entire menu, maybe opt for replacing the tunnel entries instead?
        statusMenu.removeAllItems()

        statusMenu.addItem(NSMenuItem.separator())

        let fileManager = FileManager.default

        // To check wg binary is enough to also guarentee wg-quick and wireguard-go when installed with Homebrew
        let wireguardInstalled = fileManager.fileExists(atPath: wireguardBin)

        if tunnels.isEmpty {
            statusMenu.addItem(NSMenuItem(title: "No tunnel configurations found", action: nil, keyEquivalent: ""))
        } else if !wireguardInstalled {
            NSLog("Wireguard binary not found at \(wireguardBin)")
            statusMenu.addItem(NSMenuItem(title: "Wireguard not installed! Click here for instructions",
                                          action: #selector(AppDelegate.showInstallInstructions(_:)),
                                          keyEquivalent: ""))
        } else {
            for (tunnelID, tunnel) in tunnels.sorted(by: { $0.0 < $1.0 }) {
                addTunnelMenuItem(statusMenu: statusMenu, tunnelId: tunnelID, tunnel: tunnel)
            }
        }
        statusMenu.addItem(NSMenuItem.separator())
        statusMenu.addItem(NSMenuItem(title: "About", action: #selector(AppDelegate.about(_:)), keyEquivalent: ""))
        statusMenu.addItem(NSMenuItem(title: "Quit", action: #selector(AppDelegate.quit(_:)), keyEquivalent: "q"))

        let connectedTunnels = tunnels.filter {$1.connected}
        if connectedTunnels.isEmpty {
            let icon = NSImage(named: .disabled)
            icon!.isTemplate = true
            statusItem.image = icon
        } else {
            let icon = NSImage(named: .connected)
            icon!.isTemplate = true
            statusItem.image = icon
        }
    }

    func addTunnelMenuItem(statusMenu: NSMenu, tunnelId: String, tunnel: Tunnel) {
        let item = NSMenuItem(title: "\(tunnel.interface): \(tunnel.address)",
            action: #selector(AppDelegate.toggleTunnel(_:)), keyEquivalent: "")
        item.representedObject = tunnelId
        if tunnel.connected {
            item.state = NSControl.StateValue.on
        }
        statusMenu.addItem(item)
        for peer in tunnel.peers {
            statusMenu.addItem(NSMenuItem(title: "  \(peer.endpoint): \(peer.allowedIps.joined(separator: ", "))",
                action: nil, keyEquivalent: ""))
        }
    }

    @objc func showInstallInstructions(_ sender: NSMenuItem) {
        let alert = NSAlert()
        alert.messageText = installInstructions
        alert.runModal()
    }

    // load tunnel from configuration files
    func loadConfiguration() {
        for configPath in configPaths {
            let enumerator = FileManager.default.enumerator(atPath: configPath)
            while let configFile = enumerator?.nextObject() as? String {
                if !configFile.hasSuffix(".conf") {
                    continue
                }
                NSLog("Reading config file: \(configPath)/\(configFile)")
                let interface = configFile.replacingOccurrences(of: ".conf", with: "")

                tunnels[interface] = Tunnel(
                    name: "",
                    interface: interface,
                    connected: false,
                    address: "",
                    peers: []
                )

                // determine if config file can be read
                if let ini = try? INIParser(configPath + "/" + configFile) {
                    let config = ini.sections
                    if !config.isEmpty {
                        // TODO: currently supports only one peer, need to pick a different method for parsing config
                        tunnels[interface]!.peers = [Peer(
                            endpoint: config["Peer"]!["Endpoint"]!,
                            allowedIps: config["Peer"]!["AllowedIPs"]!.split(separator: ",").map {
                                $0.trimmingCharacters(in: .whitespaces)
                            })
                        ]
                        tunnels[interface]!.address = config["Interface"]!["Address"]!
                    }
                }
            }
        }
    }

    // read runtime state of wg and update local state accordingly
    func loadState() {
        // for every configured tunnel check if a socket file exists (assume that indicates the tunnel is up)
        for tunnel in tunnels {
            let interfaceName = tunnel.key
            // TODO: more idiomatic path building?
            let name = URL(string: "\(runPath)/\(interfaceName).name")
            tunnels[interfaceName]!.connected = FileManager.default.fileExists(atPath: name!.path)
        }
    }

    @objc func quit(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(self)
    }

    @objc func about(_ sender: NSMenuItem) {
        NSApplication.shared.orderFrontStandardAboutPanel(self)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

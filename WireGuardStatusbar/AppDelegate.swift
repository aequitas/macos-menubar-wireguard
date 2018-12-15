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
    var interface = ""
    var connected = false
    var address = ""
    var peers: [Peer] = []

    var title: String { return interface }
}

extension Tunnel {
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

    init?(fromFile filePath: String) {
        if let configFile = try? String(contentsOfFile: filePath, encoding: .utf8) {
            self.init(fromConfig: configFile)
        } else {
            NSLog("Failed to read configuration file \(filePath)")
            return nil
        }
    }
}

struct Peer {
    var endpoint: String
    var allowedIps: [String]
}

var username = NSUserName()

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, SKQueueDelegate {
    var tunnels = Tunnels()

    // To check wg binary is enough to also guarentee wg-quick and wireguard-go when installed with Homebrew
    var wireguardInstalled = FileManager.default.fileExists(atPath: wireguardBin)

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    var menu = NSMenu()
    var detailedMenu = NSMenu()

    let privilegedHelper = PrivilegedHelper()

    func applicationDidFinishLaunching(_: Notification) {
        // Check if the application can connect to the helper, or if the helper has to be updated with a newer version.
        // If the helper should be updated or installed, prompt the user to do so
        privilegedHelper.helperStatus { installed in
            if !installed {
                self.privilegedHelper.installHelper()
                self.privilegedHelper.xpcHelperConnection = nil //  Nulls the connection to force a reconnection
            }
        }

        // register watchers to respond to changes in wireguard config/runtime state
        let queue = SKQueue(delegate: self)!
        for directory in configPaths + [runPath] {
            if FileManager.default.fileExists(atPath: directory) {
                NSLog("Watching \(directory) for changes")
                queue.addPath(directory)
            } else {
                NSLog("Not watching \(directory) as it doesn't exist")
            }
        }

        // do an initial state update from current configuration and runtime state
        tunnels = loadConfiguration()
        loadState()
        buildMenus()

        // override mouse click handling to enable option-click for details
        if let button = self.statusItem.button {
            button.action = #selector(statusBarButtonClicked(sender:))
            button.sendAction(on: [NSEvent.EventTypeMask.leftMouseUp, NSEvent.EventTypeMask.rightMouseUp])
        }
    }

    func buildMenus() {
        menu = buildMenu(tunnels: tunnels, details: false,
                         showInstallInstructions: !wireguardInstalled)
        detailedMenu = buildMenu(tunnels: tunnels, details: true,
                                 showInstallInstructions: !wireguardInstalled)
        DispatchQueue.main.async { self.statusItem.image = menuImage(tunnels: self.tunnels) }
    }

    @objc func statusBarButtonClicked(sender _: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        if event.modifierFlags.contains(.option) {
            statusItem.popUpMenu(detailedMenu)
        } else {
            statusItem.popUpMenu(menu)
        }
    }

    // read runtime state of wg and update local state accordingly
    func loadState() {
        // for every configured tunnel check if a socket file exists (assume that indicates the tunnel is up)
        for var tunnel in tunnels {
            tunnel.value.connected = FileManager.default.fileExists(atPath: "\(runPath)/\(tunnel.key).name")
        }
    }

    func applicationWillTerminate(_: Notification) {
//        TODO: configurable option to disable tunnels on shutdown
        let xpcService = privilegedHelper.helperConnection()?.remoteObjectProxyWithErrorHandler { error -> Void in
            NSLog("XPCService error: \(error)")
        } as? HelperProtocol

        xpcService?.shutdown()
    }

    // handle incoming file/directory change events
    func receivedNotification(_ notification: SKQueueNotification, path: String, queue _: SKQueue) {
        if configPaths.contains(path) {
            NSLog("Configuration files changed, reloading")
            tunnels = loadConfiguration()
        }
        if path == runPath {
            NSLog("Tunnel state changed, reloading")
        }
        loadState()
        buildMenus()
    }

    // bring tunnel up/down
    @objc func toggleTunnel(_ sender: NSMenuItem) {
        if let tunnelId = sender.representedObject as? String {
            let tunnel = tunnels[tunnelId]!

            let xpcService = privilegedHelper.helperConnection()?.remoteObjectProxyWithErrorHandler { error -> Void in
                NSLog("XPCService error: \(error)")
            } as? HelperProtocol

            if !tunnel.connected {
                xpcService?.tunnelUp(interface: tunnel.interface, reply: { exitStatus in
                    NSLog("Tunnel \(tunnelId) up exit status: \(exitStatus)")
                })

            } else {
                xpcService?.tunnelDown(interface: tunnel.interface, reply: { exitStatus in
                    NSLog("Tunnel \(tunnelId) down exit status: \(exitStatus)")
                })
            }
        } else {
            NSLog("Sender not convertable to String: \(sender.representedObject.debugDescription)")
        }
    }

    @objc func showInstallInstructions(_: NSMenuItem) {
        let alert = NSAlert()
        alert.messageText = installInstructions
        alert.runModal()
    }

    @objc func quit(_: NSMenuItem) {
        NSApplication.shared.terminate(self)
    }

    @objc func about(_: NSMenuItem) {
        NSApplication.shared.orderFrontStandardAboutPanel(self)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

// load tunnel from configuration files
func loadConfiguration() -> Tunnels {
    var tunnels = Tunnels()
    for configPath in configPaths {
        // TODO: directories with restricted permissions won't be iterated over without warning
        let enumerator = FileManager.default.enumerator(atPath: configPath)
        while let configFile = enumerator?.nextObject() as? String {
            // ignore non config file
            if !configFile.hasSuffix(".conf") {
                continue
            }

            let interface = configFile.replacingOccurrences(of: ".conf", with: "")

            NSLog("Reading config file: \(configPath)/\(configFile)")

            var tunnel = Tunnel(fromFile: configPath + "/" + configFile)
            if tunnel != nil {
                tunnel!.interface = interface
                tunnels[interface] = tunnel
            }
        }
    }
    return tunnels
}

// contruct menu with all tunnels found in configuration
// TODO: find out if it is possible to have a dynamic bound IB menu with variable contents
func buildMenu(tunnels: Tunnels, details: Bool = false, showInstallInstructions: Bool = false) -> NSMenu {
    // TODO: currently just rebuilding the entire menu, maybe opt for replacing the tunnel entries instead?
    let statusMenu = NSMenu()
    statusMenu.minimumWidth = 200

    statusMenu.addItem(NSMenuItem.separator())
    statusMenu.addItem(NSMenuItem(title: "About", action: #selector(AppDelegate.about(_:)), keyEquivalent: ""))
    statusMenu.addItem(NSMenuItem(title: "Quit", action: #selector(AppDelegate.quit(_:)), keyEquivalent: "q"))

    if showInstallInstructions {
        NSLog("Wireguard binary not found at \(wireguardBin)")
        statusMenu.insertItem(NSMenuItem(title: "Wireguard not installed! Click here for instructions",
                                         action: #selector(AppDelegate.showInstallInstructions(_:)),
                                         keyEquivalent: ""), at: 0)
        return statusMenu
    }

    if tunnels.isEmpty {
        statusMenu.insertItem(NSMenuItem(title: "No tunnel configurations found",
                                         action: nil, keyEquivalent: ""), at: 0)
    } else {
        for (tunnelId, tunnel) in tunnels.sorted(by: { $0.0 > $1.0 }) {
            let item = NSMenuItem(title: "\(tunnel.title)",
                                  action: #selector(AppDelegate.toggleTunnel(_:)), keyEquivalent: "")
            item.representedObject = tunnelId
            if tunnel.connected {
                item.state = NSControl.StateValue.on
            }
            if tunnel.connected || details {
                for peer in tunnel.peers {
                    statusMenu.insertItem(NSMenuItem(title: "  Allowed IPs: \(peer.allowedIps.joined(separator: ", "))",
                                                     action: nil, keyEquivalent: ""), at: 0)
                    statusMenu.insertItem(NSMenuItem(title: "  Endpoint: \(peer.endpoint)",
                                                     action: nil, keyEquivalent: ""), at: 0)
                }
                statusMenu.insertItem(NSMenuItem(title: "  Address: \(tunnel.address)",
                                                 action: nil, keyEquivalent: ""), at: 0)
            }
            statusMenu.insertItem(item, at: 0)
        }
    }

    return statusMenu
}

func menuImage(tunnels: Tunnels) -> NSImage {
    let connectedTunnels = tunnels.filter { $1.connected }
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

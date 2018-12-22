// Helper main logic

import Foundation

class Helper: NSObject, HelperProtocol, SKQueueDelegate {
    private var app: AppXPC?

    /// Starts the helper daemon
    func run() {
        // create XPC to App
        app = AppXPC(exportedObject: self,
                     onClose: { DispatchQueue.main.async { CFRunLoopStop(CFRunLoopGetCurrent()) } })

        // watch configuration and runstate directories for changes to notify App
        registerWireGuardStateWatch()

        // keep running (last XPC connection closing quits)
        // TODO: Helper needs to live for at least 10 seconds or launchd will get unhappy
        CFRunLoopRun()
    }

    func registerWireGuardStateWatch() {
        // register watchers to respond to changes in wireguard config/runtime state
        // will trigger: receivedNotification
        let queue = SKQueue(delegate: self)!
        for directory in configPaths + [runPath] {
            if FileManager.default.fileExists(atPath: directory) {
                NSLog("Watching \(directory) for changes")
                queue.addPath(directory)
            } else {
                NSLog("Not watching \(directory) as it doesn't exist")
            }
        }
    }

    // SKQueue: handle incoming file/directory change events
    func receivedNotification(_ notification: SKQueueNotification, path: String, queue _: SKQueue) {
        if configPaths.contains(path) {
            NSLog("Configuration files changed, reloading")
        }
        if path == runPath {
            NSLog("Tunnel state changed, reloading")
        }
        // TODO: only send events on actual changes (/var/run/tunnel.name, /etc/wireguard/tunnel.conf)
        // not for every change in either run or config directories
        // At first maybe simple debounce to reduce amount of reloads of configuration?

        for connection in app!.connections {
            if let remoteObject = connection.remoteObjectProxy as? AppProtocol {
                remoteObject.updateState()
            } else {
                NSLog("Failed to notify App of configuration/state changes.")
            }
        }
    }

    // XPC: return raw data to be used by App to construct tunnel configuration/state
    func getTunnels(reply: @escaping (TunnelInfo) -> Void) {
        var tunnels: TunnelInfo = [:]

        for configPath in configPaths {
            let enumerator = FileManager.default.enumerator(atPath: configPath)
            while let configFile = enumerator?.nextObject() as? String {
                // ignore non config file
                if !configFile.hasSuffix(".conf") {
                    continue
                }

                let tunnelName = configFile.replacingOccurrences(of: ".conf", with: "")
                tunnels[tunnelName] = []

                NSLog("Reading interface for tunnel \(tunnelName)")
                var interfaceName = try? String(contentsOfFile: runPath + "/" + tunnelName + ".name", encoding: .utf8)
                if interfaceName == nil {
                    interfaceName = ""
                }

                // TODO: read configuration data from wg showconf as well
                NSLog("Reading config file: \(configPath)/\(configFile)")
                var configData = try? String(contentsOfFile: configPath + "/" + configFile, encoding: .utf8)
                if configData == nil {
                    configData = ""
                }

                tunnels[tunnelName] = [interfaceName!, configData!]
            }
        }

        reply(tunnels)
    }

    // XPC: called by App to have Helper change the state of a tunnel to up or down
    func setTunnel(tunnelName: String, enable: Bool, reply: @escaping (NSNumber) -> Void) {
        let state = enable ? "up" : "down"

        if !validateTunnelName(tunnelName: tunnelName) {
            NSLog("Invalid tunnel name \(tunnelName)")
            reply(1)
            return
        }

        NSLog("Set tunnel \(tunnelName) \(state)")
        reply(wgQuick([state, tunnelName]))
    }

    // XPC: allow App to query version of helper to allow updating when a new version is available
    func getVersion(_ reply: (String) -> Void) {
        if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
            reply(version)
        } else {
            NSLog("Unable to get version information")
            reply("n/a")
        }
    }
}

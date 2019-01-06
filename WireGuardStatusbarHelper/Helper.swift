// Helper main logic

import Foundation

class Helper: NSObject, HelperProtocol, SKQueueDelegate {
    private var app: AppXPC?

    private var queue: SKQueue?

    // Starts the helper daemon
    func run() {
        // create XPC to App
        app = AppXPC(exportedObject: self, onConnect: abortShutdown, onClose: shutdown)

        // watch configuration and runstate directories for changes to notify App
        registerWireGuardStateWatch()

        // keep running (last XPC connection closing quits)
        // TODO: Helper needs to live for at least 10 seconds or launchd will get unhappy
        CFRunLoopRun()
    }

    func registerWireGuardStateWatch() {
        // register watchers to respond to changes in wireguard config/runtime state
        // will trigger: receivedNotification
        if queue == nil {
            queue = SKQueue(delegate: self)!
        }
        for directory in configPaths + [runPath] {
            // skip already watched paths
            if queue!.isPathWatched(directory) { continue }

            if FileManager.default.fileExists(atPath: directory) {
                NSLog("Watching \(directory) for changes")
                queue!.addPath(directory)
            } else {
                NSLog("Not watching '\(directory)' as it does not exist")
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

        appUpdateState()
    }

    // Send a signal to the App that tunnel state/configuration might have changed
    func appUpdateState() {
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
                    // don't descend into subdirectories
                    enumerator?.skipDescendants()
                    continue
                }

                let tunnelName = configFile.replacingOccurrences(of: ".conf", with: "")
                if tunnels[tunnelName] != nil {
                    NSLog("Skipping '\(configFile)' as this tunnel already exists from a higher configuration path.")
                    continue
                }

                NSLog("Reading interface for tunnel \(tunnelName)")
                var interfaceName = try? String(contentsOfFile: runPath + "/" + tunnelName + ".name", encoding: .utf8)
                if interfaceName == nil {
                    // tunnel is not connected
                    interfaceName = ""
                }

                // TODO: read configuration data from wg showconf as well
                NSLog("Reading config file: \(configPath)/\(configFile)")
                var configData = try? String(contentsOfFile: configPath + "/" + configFile, encoding: .utf8)
                if configData == nil {
                    NSLog("Failed to read configuration file '\(configPath)/\(configFile)'")
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
            NSLog("Invalid tunnel name '\(tunnelName)'")
            reply(1)
            return
        }

        NSLog("Set tunnel \(tunnelName) \(state)")
        reply(wgQuick([state, tunnelName]))

        // because /var/run/wireguard might not exist and can be created after upping the first tunnel
        // run the registration of watchdirectories again and force trigger a state update to the app
        registerWireGuardStateWatch()
        appUpdateState()
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

    // Launchd throttles services that restart to soon (<10 seconds), provide a mechanism to prevent this.
    // set the time in the future when it is safe to shutdown the helper without launchd penalty
    let launchdMinimaltimeExpired = DispatchTime.now() + DispatchTimeInterval.seconds(10)
    var shutdownTask: DispatchWorkItem?

    func shutdown() {
        NSLog("Shutting down")
        // Dispatch the shutdown of the runloop to at least 10 seconds after starting the application.
        // This will shutdown immidiately if the deadline already passed.
        shutdownTask = DispatchWorkItem { CFRunLoopStop(CFRunLoopGetCurrent()) }
        // Dispatch to main queue since that is the thread where the runloop is
        DispatchQueue.main.asyncAfter(deadline: launchdMinimaltimeExpired, execute: shutdownTask!)
    }

    // allow shutdown to be aborted (eg: when a new XPC connection comes in)
    func abortShutdown() {
        if let shutdownTask = self.shutdownTask {
            NSLog("Aborting shutdown")
            shutdownTask.cancel()
            self.shutdownTask = nil
        }
    }
}

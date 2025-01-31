// Helper main logic

import Foundation

// amount of ms to debounce filesystem events to prevent sending update notifications to the App to often
let fseventDebounce = 100

class Helper: NSObject, HelperProtocol, SKQueueDelegate {
    private var app: AppXPC?

    private var queue: SKQueue?

    // Prefix path for etc/wireguard, bin/wg, bin/wireguard-go and bin/bash (bash 4),
    // can be overridden by the user via root defaults to allow custom location for Homebrew.
    private var brewPrefix: String
    // Path to wg-quick, can be overriden by the user via root defaults.
    // NOTICE: the root defaults override feature is a half implemented feature
    // the GUI App will not be aware of these settings and might falsely warn that WireGuard
    // is not installed. This warning can be ignored.
    // Example, to set defaults as root for wgquickBinPath run:
    // sudo defaults write WireGuardStatusbarHelper wgquickBinPath /opt/local/bin/wg-quick
    private var wgquickBinPath: String
    // Path use to determine if WireGuard Homebrew package is installed and query wg for tunnel names and configuration
    // To check wg binary is enough to also guarentee wg-quick and wireguard-go when installed with Homebrew.
    private var wireguardBinPath: String

    let defaults = UserDefaults.standard

    let wireguard: WireGuard

    // Read preferences set via root defaults.
    override init() {
        defaults.register(defaults: DefaultSettings.Helper)

        brewPrefix = defaults.string(forKey: "brewPrefix")!
        if brewPrefix != DefaultSettings.Helper["brewPrefix"] {
            NSLog("Overriding 'brewPrefix' with: \(brewPrefix)")
        }
        wireguardBinPath = "\(brewPrefix)/bin/wg"

        wgquickBinPath = "\(brewPrefix)/bin/wg-quick"
        if let wgquickBinPath = defaults.string(forKey: "wgquickBinPath"), wgquickBinPath != "" {
            NSLog("Overriding 'wgquickBinPath' with: \(wgquickBinPath)")
            self.wgquickBinPath = wgquickBinPath
        }

        wireguard = WireGuard(
            brewPrefix: brewPrefix,
            wireguardBinPath: wireguardBinPath,
            wgquickBinPath: wgquickBinPath,
            configPaths: configPaths,
            runPath: runPath
        )
    }

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

    var debounceFilesystemEvents: DispatchWorkItem?

    // SKQueue: handle incoming file/directory change events
    func receivedNotification(_: SKQueueNotification, path: String, queue _: SKQueue) {
        if configPaths.contains(path) {
            NSLog("Configuration files changed, reloading")
        }
        if path == runPath {
            NSLog("Tunnel state changed, reloading")
        }
        // TODO: only send events on actual changes (/var/run/tunnel.name, /etc/wireguard/tunnel.conf)
        // not for every change in either run or config directories

        // prevent sending notifications about changes to config/runtime state to fast after another
        if debounceFilesystemEvents == nil {
            debounceFilesystemEvents = DispatchWorkItem {
                self.debounceFilesystemEvents = nil
                self.appUpdateState()
            }
            let deadline = DispatchTime.now() + DispatchTimeInterval.milliseconds(fseventDebounce)
            DispatchQueue.main.asyncAfter(deadline: deadline,
                                          execute: debounceFilesystemEvents!)
        }
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
        reply(Dictionary(uniqueKeysWithValues: wireguard.tunnelNames().map { tunnelName in
            (tunnelName, [wireguard.interfaceName(tunnelName), wireguard.tunnelConfig(tunnelName)])
        }))
    }

    // XPC: called by App to have Helper change the state of a tunnel to up or down
    func setTunnel(tunnelName: String, enable: Bool, reply:
        @escaping (_ success: Bool, _ errorMessage: String) -> Void)
    {
        let state = enable ? "up" : "down"

        if !WireGuard.validateTunnelName(tunnelName: tunnelName) {
            NSLog("Invalid tunnel name '\(tunnelName)'")
            reply(false, "Invalid tunnel name '\(tunnelName)'")
            return
        }

        NSLog("Set tunnel \(tunnelName) \(state)")
        let (success, errorMessage) = wireguard.wgQuick([state, tunnelName])
        reply(success, errorMessage)

        // Because /var/run/wireguard might not exist and can be created after upping the first tunnel
        // run the registration of watchdirectories again and force trigger a state update to the app.
        // This is 'cheaper' than registering a watcher for the parent directory /var/run/.
        registerWireGuardStateWatch()

        // Notify the app to have it pull in changes.
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

    func wireguardInstalled(_ reply: (Bool) -> Void) {
        let wireguardInstalled = FileManager.default.fileExists(atPath: wireguardBinPath)
        let wgquickInstalled = FileManager.default.fileExists(atPath: wgquickBinPath)
        reply(wgquickInstalled && wireguardInstalled)
    }

    // Launchd throttles services that restart to soon (<10 seconds), provide a mechanism to prevent this.
    // set the time in the future when it is safe to shutdown the helper without launchd penalty
    let launchdMinimaltimeExpired = DispatchTime.now() + DispatchTimeInterval.seconds(10)
    var shutdownTask: DispatchWorkItem?

    func shutdown() {
        NSLog("Going to shut down")
        // Dispatch the shutdown of the runloop to at least 10 seconds after starting the application.
        // This will shutdown immidiately if the deadline already passed.
        shutdownTask = DispatchWorkItem {
            CFRunLoopStop(CFRunLoopGetCurrent())
            NSLog("Shutting down")
        }
        // Dispatch to main queue since that is the thread where the runloop is
        DispatchQueue.main.asyncAfter(deadline: launchdMinimaltimeExpired, execute: shutdownTask!)
    }

    // allow shutdown to be aborted (eg: when a new XPC connection comes in)
    func abortShutdown() {
        if let shutdownTask = shutdownTask {
            NSLog("Aborting shutdown")
            shutdownTask.cancel()
            self.shutdownTask = nil
        }
    }
}

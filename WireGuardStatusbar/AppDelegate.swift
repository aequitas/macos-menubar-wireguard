// Main Application logic and UI glue

import Cocoa

// make logging in debug more compact (no timestamp/process name/pid)
#if DEBUG
    let NSLog = customLog
    public func customLog(_ format: String, _ args: CVarArg...) {
        withVaList(args) { print(NSString(format: format, arguments: $0)) }
    }
#endif

extension NSImage.Name {
    static let connected = "silhouette"
    static let enabled = "silhouette-dim"
    static let disabled = "dragon"
    static let appInit = "dragon-dim"
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, AppProtocol {
    // keep the existence and state of all tunnel(configuration)s
    var tunnels = Tunnels()

    // To check wg binary is enough to also guarentee wg-quick and wireguard-go when installed with Homebrew
    var wireguardInstalled = FileManager.default.fileExists(atPath: wireguardBin)

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    var privilegedHelper: HelperXPC?

    func applicationDidFinishLaunching(_: Notification) {
        // set a default icon at startup
        statusItem.image = NSImage(named: .appInit)!
        statusItem.image!.isTemplate = true

        // override mouse click handling to enable option-click for details
        if let button = self.statusItem.button {
            button.action = #selector(statusBarButtonClicked(sender:))
            button.sendAction(on: [NSEvent.EventTypeMask.leftMouseDown, NSEvent.EventTypeMask.rightMouseDown])
        }

        // initialize helper,
        privilegedHelper = HelperXPC(exportedObject: self)

        // install the Helper or Update it if needed
        privilegedHelper!.installOrUpdateHelper(
            // if installation failed alert user
            onFailure: alertHelperFailure,
            // if helper is up to date, installed or updated, get initial tunnel state
            onSuccess: updateState
        )
    }

    // notify user of failed helper install
    func alertHelperFailure() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Failed to install or update Privileged Helper. Please check logs."
            alert.runModal()
        }
    }

    // build menu on the fly using tunnels state/configuration
    @objc func statusBarButtonClicked(sender _: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        let details = event.modifierFlags.contains(.option)

        statusItem.popUpMenu(buildMenu(tunnels: tunnels, details: details,
                                       showInstallInstructions: !wireguardInstalled))
    }

    // query the Helper for all current tunnels configuration and runtime state, update menu icon
    func updateState() {
        NSLog("Updating tunnel configuration and runtime state.")

        let xpcService = privilegedHelper?.helperConnection()?.remoteObjectProxyWithErrorHandler { error -> Void in
            NSLog("XPCService error: \(error)")
            return
        } as? HelperProtocol

        xpcService?.getTunnels(reply: { tunnelInfo in
            self.tunnels = tunnelInfo.mapValues { interfaceAndConfigData in
                return Tunnel(fromTunnelInfo: interfaceAndConfigData)
            }
            DispatchQueue.main.async { self.statusItem.image = menuImage(tunnels: self.tunnels) }
        })
    }

    // bring tunnel up/down
    @objc func toggleTunnel(_ sender: NSMenuItem) {
        if let tunnelName = sender.representedObject as? String {
            let tunnel = tunnels[tunnelName]!

            let xpcService = privilegedHelper!.helperConnection()?.remoteObjectProxyWithErrorHandler { error -> Void in
                NSLog("XPCService error: \(error)")
            } as? HelperProtocol

            xpcService?.setTunnel(tunnelName: tunnelName, enable: !tunnel.connected, reply: { exitStatus in
                NSLog("setTunnel \(tunnelName), to: \(!tunnel.connected), exit status: \(exitStatus)")
            })
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

    func applicationWillTerminate(_: Notification) {
        //        TODO: configurable option to disable tunnels on shutdown
    }
}

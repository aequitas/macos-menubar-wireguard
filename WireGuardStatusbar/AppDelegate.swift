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
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, AppProtocol {
    let defaults: UserDefaults = NSUserDefaultsController.shared.defaults

    // keep the existence and state of all tunnel(configuration)s
    var tunnels = Tunnels()

    // To check wg binary is enough to also guarentee wg-quick and wireguard-go when installed with Homebrew
    @objc dynamic let wireguardInstalled = FileManager.default.fileExists(atPath: wireguardBinPath)

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    @IBOutlet var menu: NSMenu!

    var privilegedHelper: HelperXPC?

    func applicationDidFinishLaunching(_: Notification) {
        // set default preferences
        defaults.register(defaults: defaultSettings)

        #if DEBUG
            // reset preferences to defaults for development/(ui)testing
            defaults.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        #endif

        // set a default icon at startup
        statusItem.image = NSImage(named: .appInit)!
        statusItem.image!.isTemplate = true

        // configure menu to use and set delegate to allow overriding menu option modifier behaviour
        statusItem.menu = menu
        menu.minimumWidth = 200

        // initialize helper XPC connection
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

    @objc func menuNeedsUpdate(_ menu: NSMenu) {
        // show details if menu is invoked while pressing down option key
        let optionModifier = NSApp.currentEvent!.modifierFlags.contains(.option)
        let showAllTunnelDetails = defaults.bool(forKey: "showAllTunnelDetails")
        let showDetails = optionModifier || showAllTunnelDetails
        let showConnected = defaults.bool(forKey: "showConnectedTunnelDetails")

        // remove all tunnel and tunnel detail menu items
        while let item = menu.item(withTag: MenuItemTypes.tunnel.rawValue) {
            menu.removeItem(item)
        }

        // generate new tunnel and tunnel details menu items and add them to the menu
        let tunnelMenuItems = buildMenu(tunnels: tunnels,
                                        allTunnelDetails: showDetails,
                                        connectedTunnelDetails: showConnected)
        for item in tunnelMenuItems.reversed() {
            item.tag = MenuItemTypes.tunnel.rawValue
            menu.insertItem(item, at: 0)
        }
    }

    // query the Helper for all current tunnels configuration and runtime state, update menu icon
    func updateState() {
        NSLog("Updating tunnel configuration and runtime state.")

        let xpcService = privilegedHelper?.helperConnection()?.remoteObjectProxyWithErrorHandler { error -> Void in
            NSLog("XPCService error: \(error)")
            return
        } as? HelperProtocol

        xpcService?.getTunnels(reply: { tunnelInfo in
            self.tunnels = tunnelInfo.map { name, interfaceAndConfigData in
                return Tunnel(name: name, fromTunnelInfo: interfaceAndConfigData)
            }
            DispatchQueue.main.async { self.statusItem.image = menuImage(tunnels: self.tunnels) }
        })
    }

    // bring tunnel up/down
    @objc func toggleTunnel(_ sender: NSMenuItem) {
        if let tunnelName = sender.representedObject as? String {
            let tunnel = tunnels.filter { $0.name == tunnelName }[0]

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

    @IBAction func showInstallInstructions(_: Any) {
        let alert = NSAlert()
        alert.messageText = installInstructions
        alert.runModal()
    }

    @IBAction func about(_: Any) {
        NSApplication.shared.orderFrontStandardAboutPanel(self)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var preferences: NSWindowController?
    @IBAction func preferences(_: Any) {
        if preferences == nil {
            preferences = Preferences()
        }
        preferences!.showWindow(nil)
    }

    @IBAction func quit(_: Any) {
        NSApplication.shared.terminate(self)
    }

    func applicationWillTerminate(_: Notification) {
        //        TODO: configurable option to disable tunnels on shutdown
    }
}

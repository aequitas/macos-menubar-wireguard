// Helper main logic

import Foundation

class Helper: NSObject, HelperProtocol, NSXPCListenerDelegate {
    var listener: NSXPCListener

    let wireguard = WireGuard()

    override init() {
        listener = NSXPCListener(machServiceName: HelperConstants.machServiceName)
        super.init()
        listener.delegate = self
    }

    /// Starts the helper daemon
    func run() {
        listener.resume()

        RunLoop.current.run()
    }

    /// Called when the client connects to the helper daemon
    func listener(_: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
        connection.exportedObject = self
        connection.resume()

        return true
    }

    func setTunnel(tunnelName: String, enable: Bool, reply: @escaping (NSNumber) -> Void) {
        let state = enable ? "up" : "down"
        NSLog("Set tunnel \(tunnelName) \(state)")
        reply(wireguard.wg([state, tunnelName]))
    }

    /// Return daemon's bundle version
    /// Because communication over XPC is asynchronous, all methods in the protocol must have a return type of void
    func getVersion(_ reply: (String) -> Void) {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        if version != nil {
            reply(version!)
        } else {
            reply("")
        }
    }

    func shutdown() {
        NSLog("Shutting down WireGuardStatusbar Helper....")
        exit(0)
    }
}

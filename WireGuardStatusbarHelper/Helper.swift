//
//  Helper.swift
//  WireGuardStatusbarHelper
//
//  Created by Johan Bloemberg on 11/08/2018.
//  Copyright © 2018 Johan Bloemberg. All rights reserved.
//

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

    func tunnelUp(interface: String, reply: @escaping (NSNumber) -> Void) {
        NSLog("Bringing interface \(interface) up")
        reply(wireguard.wg(["up", interface]))
    }

    func tunnelDown(interface: String, reply: @escaping (NSNumber) -> Void) {
        NSLog("Bringing interface \(interface) down")
        reply(wireguard.wg(["down", interface]))
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

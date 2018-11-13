//
//  Protocol.swift
//  HelperTool
//
//  Created by Johan Bloemberg on 11/08/2018.
//  Copyright © 2018 Johan Bloemberg. All rights reserved.
//

import Foundation

struct HelperConstants {
    static let machServiceName = "nl.ijohan.WireguardStatusbarHelper"
}

/// Protocol with inter process method invocation methods that ProcessHelper supports
/// Because communication over XPC is asynchronous, all methods in the protocol must have a return type of void
@objc(HelperProtocol)
protocol HelperProtocol {
    func tunnelUp(interface: String, reply: @escaping (NSNumber) -> Void)
    func tunnelDown(interface: String, reply: @escaping (NSNumber) -> Void)
    func getVersion(_ reply: (String) -> Void)
}

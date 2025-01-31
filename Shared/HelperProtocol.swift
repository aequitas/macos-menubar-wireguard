// Functions that can be invoked by App on the Helper via XPC

import Foundation

enum HelperConstants {
    static let machServiceName = "WireGuardStatusbarHelper"
}

/// Protocol with inter process method invocation methods that ProcessHelper supports
/// Because communication over XPC is asynchronous, all methods in the protocol must have a return type of void
@objc(HelperProtocol)
protocol HelperProtocol {
    func getTunnels(reply: @escaping (TunnelInfo) -> Void)
    func setTunnel(tunnelName: String, enable: Bool, reply: @escaping (_ success: Bool, _ errorMessage: String) -> Void)
    func getVersion(_ reply: @escaping (String) -> Void)
    func wireguardInstalled(_ reply: @escaping (Bool) -> Void)
}

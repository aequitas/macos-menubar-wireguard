// Functions that can be invoked by Helper on the App via XPC

import Foundation

/// Protocol with inter process method invocation methods that App supports
/// Because communication over XPC is asynchronous, all methods in the protocol must have a return type of void
@objc(AppProtocol)
protocol AppProtocol {
    func updateState()
}

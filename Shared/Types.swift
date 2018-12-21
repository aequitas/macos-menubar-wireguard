// Types shared between the App and the Helper

import Foundation

// Since NSXPC does not support more complex Swift types like structs or dict these types are kept simple.

// name of the tunnel (config file name without .conf)
typealias TunnelName = String
// name of the associated interface with the tunnel (eg: utun1)
typealias TunnelInterface = String
// contents of a configuration file or configuration dump from `wg showconf`
typealias ConfigData = String

// used to transfer all current tunnel configuration and state from Helper to App
typealias TunnelInfo = [String: [TunnelInterfaceOrConfigData]]
typealias TunnelInterfaceOrConfigData = String

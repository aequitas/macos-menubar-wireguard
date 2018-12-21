// XPC connection logic

import Foundation

class AppXPC: NSObject, NSXPCListenerDelegate {
    private let listener: NSXPCListener

    private var exportedObject: HelperProtocol?
    private var onClose: () -> Void

    var connections = [NSXPCConnection]()

    let connectionListActions = DispatchQueue(label: "connectionListActions")

    init(exportedObject: HelperProtocol, onClose: @escaping () -> Void) {
        self.exportedObject = exportedObject
        self.onClose = onClose

        listener = NSXPCListener(machServiceName: HelperConstants.machServiceName)
        super.init()
        listener.delegate = self
        listener.resume()
    }

    /// Called when the client connects to the helper daemon
    func listener(_: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        NSLog("Client connected")

        // Set the protocol that the calling application conforms to.
        connection.remoteObjectInterface = NSXPCInterface(with: AppProtocol.self)

        // Set the protocol that the helper conforms to.
        connection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
        connection.exportedObject = exportedObject

        // Set the invalidation handler to remove this connection when it's work is completed.
        connection.invalidationHandler = {
            self.connectionListActions.sync {
                if let connectionIndex = self.connections.firstIndex(of: connection) {
                    self.connections.remove(at: connectionIndex)
                }

                if self.connections.isEmpty {
                    NSLog("No more connections.")
                    self.onClose()
                }
            }
        }

        connectionListActions.sync {
            connections.append(connection)
        }
        connection.resume()

        return true
    }
}

// XPC connection logic and Helper utility functions

import Foundation
import ServiceManagement

class HelperXPC {
    var xpcHelperConnection: NSXPCConnection?
    var exportedObject: AppProtocol?

    init(exportedObject: AppProtocol) {
        self.exportedObject = exportedObject
    }

    func installOrUpdateHelper(onFailure: @escaping (String?) -> Void, onSuccess: @escaping () -> Void) {
        helperStatus { installed in
            if !installed {
                // Invalidate the connection to force a reconnect to the newly installed helper
                self.xpcHelperConnection?.invalidate()
                self.xpcHelperConnection = nil

                if let error = self.installHelper() {
                    onFailure(error)
                    return
                }
                self.helperStatus { installed in
                    if !installed {
                        onFailure("Helper not correct version after install. If downgrading, uninstall first.")
                    }
                }
            }
            onSuccess()
        }
    }

    func helper(_ completion: ((Bool) -> Void)?) -> HelperProtocol? {
        // Get the current helper connection and return the remote object (Helper.swift)
        // as a proxy object to call functions on.
        guard let helper = helperConnection()?.remoteObjectProxyWithErrorHandler({ _ in
            if let onCompletion = completion { onCompletion(false) }
        }) as? HelperProtocol else { return nil }
        return helper
    }

    func helperStatus(completion: @escaping (_ installed: Bool) -> Void) {
        // Comppare the CFBundleShortVersionString from the Info.plist in the helper inside our application
        // bundle with the one on disk.
        let helperURL = Bundle.main.bundleURL.appendingPathComponent(
            "Contents/Library/LaunchServices/" + HelperConstants.machServiceName
        )
        guard
            let helperBundleInfo = CFBundleCopyInfoDictionaryForURL(helperURL as CFURL) as? [String: Any],
            let helperVersion = helperBundleInfo["CFBundleVersion"] as? String,
            let helper = helper(completion)
        else {
            NSLog("Helper: Failed to get Bundled helper version")
            completion(false)
            return
        }
        NSLog("Helper: Bundle Version => \(String(describing: helperVersion))")

        helper.getVersion { installedHelperVersion in
            NSLog("Helper: Installed Version => \(String(describing: installedHelperVersion))")
            completion(installedHelperVersion == helperVersion)
        }
    }

    // Uses SMJobBless to install or update the helper tool
    func installHelper() -> String? {
        var authRef: AuthorizationRef?
        var authItem = AuthorizationItem(name: kSMRightBlessPrivilegedHelper, valueLength: 0,
                                         value: UnsafeMutableRawPointer(bitPattern: 0), flags: 0)
        var authRights = AuthorizationRights(count: 1, items: &authItem)
        let authFlags: AuthorizationFlags = [[], .extendRights, .interactionAllowed, .preAuthorize]

        let status = AuthorizationCreate(&authRights, nil, authFlags, &authRef)
        if status != errAuthorizationSuccess {
            let error = NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: nil)
            NSLog("Authorization error: \(error)")
            return "Authorization error: \(error)"
        } else {
            var cfError: Unmanaged<CFError>?
            if !SMJobBless(kSMDomainSystemLaunchd, HelperConstants.machServiceName as CFString, authRef, &cfError) {
                let blessError = cfError!.takeRetainedValue() as Error
                NSLog("Bless Error: \(blessError)")
                return "Bless Error: \(blessError)"
            }
            NSLog("\(HelperConstants.machServiceName) installed successfully")
        }

        return nil
    }

    func helperConnection() -> NSXPCConnection? {
        if xpcHelperConnection != nil {
            return xpcHelperConnection
        }

        xpcHelperConnection = NSXPCConnection(machServiceName: HelperConstants.machServiceName,
                                              options: .privileged)
        if xpcHelperConnection == nil {
            NSLog("Failed to setup XPC connection")
            return nil
        }

        xpcHelperConnection!.exportedInterface = NSXPCInterface(with: AppProtocol.self)
        xpcHelperConnection!.exportedObject = exportedObject

        xpcHelperConnection!.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)
        xpcHelperConnection!.invalidationHandler = {
            self.xpcHelperConnection?.invalidationHandler = nil
            OperationQueue.main.addOperation {
                self.xpcHelperConnection = nil
                NSLog("XPC Connection Invalidated")
            }
        }
        xpcHelperConnection?.resume()
        NSLog("XPC Connection established")

        return xpcHelperConnection
    }
}

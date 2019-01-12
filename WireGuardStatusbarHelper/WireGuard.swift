// Interface with WireGuard using `wg-quick` or `wg` processes

import Foundation

struct WireGuard {
    let brewPrefix: String
    let wireguardBinPath: String
    let wgquickBinPath: String
    let configPaths: [String]
    let runPath: String

    // swiftlint:disable:next force_try
    static let tunnelNameRegex = try! NSRegularExpression(pattern: "^[a-zA-Z0-9_=+.-]{1,15}$")

    static func validateTunnelName(tunnelName: String) -> Bool {
        return tunnelNameRegex.firstMatch(in: tunnelName,
                                          range: NSRange(location: 0, length: tunnelName.count)) != nil
    }

    // censor sensitive information like private keys from configuration data
    static func censorConfigurationData(_ configData: String) -> String {
        // swiftlint:disable:next force_try
        let censorPrivateKey = try! NSRegularExpression(pattern: "^(PrivateKey|PresharedKey).*$",
                                                        options: [.anchorsMatchLines, .caseInsensitive])

        return censorPrivateKey.stringByReplacingMatches(in: configData,
                                                         options: [],
                                                         range: NSRange(location: 0, length: configData.count),
                                                         withTemplate: "PrivateKey = ***")
    }

    // return a list of tunnel names from configuration files or active tunnels
    func tunnelNames() -> [String] {
        var tunnelNames = [String]()

        // get names of all tunnel configurations
        for configPath in configPaths {
            let enumerator = FileManager.default.enumerator(atPath: configPath)
            while let configFile = enumerator?.nextObject() as? String {
                // ignore non config file
                if !configFile.hasSuffix(".conf") {
                    // don't descend into subdirectories
                    enumerator?.skipDescendants()
                    continue
                }

                let tunnelName = configFile.replacingOccurrences(of: ".conf", with: "")
                if tunnelNames.contains(tunnelName) {
                    NSLog("Skipping '\(configFile)' as this tunnel already exists from a higher configuration path.")
                } else {
                    tunnelNames.append(tunnelName)
                }
            }
        }
        return tunnelNames
    }

    // return name of tunnel interface (if tunnel is connected)
    func interfaceName(_ tunnelName: String) -> String {
        NSLog("Reading interface name for tunnel \(tunnelName)")
        var interfaceName: String
        if let tunnelNameFileContents = try? String(contentsOfFile: runPath + "/" + tunnelName + ".name",
                                                    encoding: .utf8) {
            interfaceName = tunnelNameFileContents.trimmingCharacters(in: NSCharacterSet.whitespacesAndNewlines)
        } else {
            // tunnel is not connected
            interfaceName = ""
        }
        return interfaceName
    }

    // return configuration for tunnel
    func tunnelConfig(_ tunnelName: String) -> String {
        for configPath in configPaths {
            let configFile = "\(configPath)/\(tunnelName).conf"

            // TODO: read configuration data from wg showconf as well
            NSLog("Reading config file: \(configFile)")
            if let configFileContents = try? String(contentsOfFile: configFile,
                                                    encoding: .utf8) {
                return WireGuard.censorConfigurationData(configFileContents)
            }
        }
        NSLog("Could not find configuration file for tunnel '\(tunnelName)'")
        return ""
    }

    func wg(_ arguments: [String]) -> Process {
        let task = Process()
        task.launchPath = wireguardBinPath
        task.arguments = arguments
        let outpipe = Pipe()
        task.standardOutput = outpipe
        let errpipe = Pipe()
        task.standardError = errpipe
        task.launch()
        task.waitUntilExit()

        return task
    }

    func wgQuick(_ arguments: [String]) -> (Bool, String) {
        // prevent passing an invalid path or else task.launch will result in a fatal NSInvalidArgumentException
        guard FileManager.default.fileExists(atPath: wgquickBinPath) else {
            NSLog("Path '\(wgquickBinPath)' for 'wg-quick' binary is invalid!")
            return (false, "Path '\(wgquickBinPath)' for 'wg-quick' binary is invalid!")
        }

        let task = Process()
        task.launchPath = wgquickBinPath
        task.arguments = arguments
        // Add brew bin to path as wg-quick requires Bash 4 instead of macOS provided Bash 3
        task.environment = ["PATH": "\(brewPrefix)/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"]
        let outpipe = Pipe()
        task.standardOutput = outpipe
        let errpipe = Pipe()
        task.standardError = errpipe
        task.launch()
        task.waitUntilExit()
        NSLog("Exit code: \(task.terminationStatus)")
        let outdata = outpipe.fileHandleForReading.readDataToEndOfFile()
        NSLog(String(data: outdata, encoding: String.Encoding.utf8)!)
        let errdata = errpipe.fileHandleForReading.readDataToEndOfFile()
        NSLog(String(data: errdata, encoding: String.Encoding.utf8)!)

        return (task.terminationStatus == 0, String(data: errdata, encoding: String.Encoding.utf8)!)
    }
}

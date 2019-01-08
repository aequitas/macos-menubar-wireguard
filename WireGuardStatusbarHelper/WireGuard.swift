// Interface with WireGuard using `wg-quick` or `wg` processes

import Foundation

// swiftlint:disable:next force_try
let tunnelNameRegex = try! NSRegularExpression(pattern: "^[a-zA-Z0-9_=+.-]{1,15}$")

func validateTunnelName(tunnelName: String) -> Bool {
    return tunnelNameRegex.firstMatch(in: tunnelName,
                                      range: NSRange(location: 0, length: tunnelName.count)) != nil
}

// censor sensitive information like private keys from configuration data
func censorConfigurationData(_ configData: String) -> String {
    // swiftlint:disable:next force_try
    let censorPrivateKey = try! NSRegularExpression(pattern: "^PrivateKey.*$",
                                                    options: [.anchorsMatchLines, .caseInsensitive])

    return censorPrivateKey.stringByReplacingMatches(in: configData,
                                                     options: [],
                                                     range: NSRange(location: 0, length: configData.count),
                                                     withTemplate: "PrivateKey = ***")
}

func wgQuick(_ arguments: [String], brewPrefix: String, wgquickBinPath: String) -> NSNumber {
    // prevent passing an invalid path or else task.launch will result in a fatal NSInvalidArgumentException
    guard FileManager.default.fileExists(atPath: wgquickBinPath) else {
        NSLog("Path '\(wgquickBinPath)' for 'wg-quick' binary is invalid!")
        return 1
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

    return task.terminationStatus as NSNumber
}

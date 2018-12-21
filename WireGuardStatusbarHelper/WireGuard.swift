// Interface with WireGuard using `wg-quick` or `wg` processes

import Foundation

public class WireGuard {
    func wg(_ arguments: [String]) -> NSNumber {
        let task = Process()
        task.launchPath = wgquickBin
        task.arguments = arguments
        // Add brew bin to path as wg-quick requires Bash 4 instead of macOS provided Bash 3
        task.environment = ["PATH": "\(brewPrefix)/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"]
        let outpipe = Pipe()
        task.standardOutput = outpipe
        let errpipe = Pipe()
        task.standardError = errpipe
        NSLog("Running command: \(task.description)")
        task.launch()
        task.waitUntilExit()
        NSLog("Exit code: \(task.terminationStatus)")
        let outdata = outpipe.fileHandleForReading.readDataToEndOfFile()
        NSLog(String(data: outdata, encoding: String.Encoding.utf8)!)
        let errdata = errpipe.fileHandleForReading.readDataToEndOfFile()
        NSLog(String(data: errdata, encoding: String.Encoding.utf8)!)

        return task.terminationStatus as NSNumber
    }
}

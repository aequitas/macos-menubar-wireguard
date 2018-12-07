//
//  WireGuard.swift
//  WireGuardStatusbarHelper
//
//  Created by Johan Bloemberg on 07/12/2018.
//  Copyright © 2018 Johan Bloemberg. All rights reserved.
//

import Foundation

public class WireGuard {    
    func wg(_ arguments:[String]) -> NSNumber {
        let task = Process()
        task.launchPath = "\(brew_prefix)/bin/wg-quick"
        task.arguments = arguments
        task.environment = ["PATH": "\(brew_prefix)/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"]
        let outpipe = Pipe()
        task.standardOutput = outpipe
        let errpipe = Pipe()
        task.standardError = errpipe
        
        task.launch()
        task.waitUntilExit()
        NSLog("\(task.terminationStatus)")
        let outdata = outpipe.fileHandleForReading.readDataToEndOfFile()
        NSLog(String(data: outdata, encoding: String.Encoding.utf8)!)
        let errdata = errpipe.fileHandleForReading.readDataToEndOfFile()
        NSLog(String(data: errdata, encoding: String.Encoding.utf8)!)
        
        return task.terminationStatus as NSNumber
    }
}

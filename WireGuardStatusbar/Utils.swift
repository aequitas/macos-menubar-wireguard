//
//  Utils.swift
//  WireGuardStatusbar
//
//  Created by Johan Bloemberg on 12/08/2018.
//  Copyright © 2018 Johan Bloemberg. All rights reserved.
//

import Foundation

@discardableResult
func shell(_ args: String...) -> String {
    let task = Process()
    task.launchPath = "/usr/bin/env"
    task.arguments = args

    let pipe = Pipe()
    task.standardOutput = pipe

    task.launch()
    task.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()

    guard let output: String = String(data: data, encoding: .utf8) else {
        return ""
    }
    return output
}

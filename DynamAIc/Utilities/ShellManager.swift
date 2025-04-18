//
//  ShellManager.swift
//  DynamAIc
//
//  Created by Jonathan Melitski on 4/16/25.
//

import Foundation

class ShellManager {
    enum ShellError: Error {
      case nonZeroExit(code: Int, output: String)
    }
    
    // From stackoverflow 26971240
    @discardableResult // Add to suppress warnings when you don't want/need a result
    static func safeShell(_ command: String) throws -> String {
        let task = Process()
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", command]
        task.executableURL = URL(fileURLWithPath: "/bin/zsh") //<--updated
        task.standardInput = nil

        try task.run() //<--updated
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)!
        
        return output
    }
    
    static func runShell(
      executableURL: URL,
      arguments: [String],
      currentDirectoryURL: URL) throws -> String {
      let process = Process()
      process.executableURL = executableURL
      process.arguments = arguments
      process.currentDirectoryURL = currentDirectoryURL

      let pipe = Pipe()
      process.standardOutput = pipe
      process.standardError  = pipe

      try process.run()
      process.waitUntilExit()

      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      let output = String(data: data, encoding: .utf8)!

      if process.terminationStatus != 0 {
        throw ShellError.nonZeroExit(code: Int(process.terminationStatus), output: output)
      }
      return output
    }
}

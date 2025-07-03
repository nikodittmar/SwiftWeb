//
//  DotEnv.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 7/2/25.
//
import Foundation

public func loadDotEnv(from url: URL) throws {

    guard let fileContents = try? String(contentsOf: url, encoding: .utf8) else {
        throw DotEnvError.notFound
    }

    let lines = fileContents.split(whereSeparator: \.isNewline)
    
    for line in lines {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedLine.isEmpty || trimmedLine.starts(with: "#") {
            continue
        }

        let parts = trimmedLine.split(separator: "=", maxSplits: 1)
        if parts.count == 2 {
            let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
            let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
            
            setenv(key, value, 1)
        }
    }
}

func setDatabaseNameInEnv(_ dbName: String, path: String = ".env") throws {
    let fileURL = URL(fileURLWithPath: path)
    var newLines: [String] = []
    var keyFound = false

    if let fileContents = try? String(contentsOf: fileURL, encoding: .utf8) {
        let lines = fileContents.split(whereSeparator: \.isNewline)
        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("DATABASE_NAME=") {
                newLines.append("DATABASE_NAME=\(dbName)")
                keyFound = true
            } else {
                newLines.append(String(line))
            }
        }
    }

    if !keyFound {
        newLines.append("DATABASE_NAME=\(dbName)")
    }

    let newContents = newLines.joined(separator: "\n")
    try newContents.write(to: fileURL, atomically: true, encoding: .utf8)
}

enum DotEnvError: Error {
    case notFound
}
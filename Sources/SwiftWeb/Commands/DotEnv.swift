//
//  GenerateCommand.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 7/2/25.
//

import Logging
import Foundation

func loadDotEnv(from url: URL, logger: Logger? = nil) throws {

    guard ProcessInfo.processInfo.environment["ENVIRONMENT"] ?? "development" == "development" else {
        return
    }

    if let logger = logger {
        logger.debug("Loading .env file for development.")
    } else {
        print(swiftweb: "📁 Loading .env file for development")
    }

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

enum DotEnvError: Error {
    case notFound
}

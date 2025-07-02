//
//  ProjectGenerator.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 7/1/25.
//

import Foundation

struct ProjectGenerator {
    let projectName: String
    let fileManager = FileManager.default

    init(projectName: String) {
        self.projectName = projectName
    }

    func generate() throws {
        guard let templateURL = Bundle.module.url(forResource: "ProjectTemplate", withExtension: nil) else {
            fatalError("ProjectTemplate directory not found. Check your Package.swift resources.")
        }
        
        let destinationURL = URL(fileURLWithPath: fileManager.currentDirectoryPath).appendingPathComponent(projectName)
        
        print("🚀 Generating new SwiftWeb project '\(projectName)'...")

        try copyTemplate(from: templateURL, to: destinationURL)

        print("✅ Project generated successfully!")
        print("\nTo get started:")
        print("  cd \(projectName)")
        print("  swift run")
    }

    
    private func copyTemplate(from sourceURL: URL, to destinationURL: URL) throws {
        guard let enumerator = fileManager.enumerator(
            at: sourceURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [],
            errorHandler: nil
        ) else {
            struct GenerationError: Error, LocalizedError {
                var errorDescription: String? = "Failed to create a file enumerator for the template directory."
            }
            throw GenerationError()
        }

        try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)

        for case let sourceItemURL as URL in enumerator {
            var relativePath = sourceItemURL.path.replacingOccurrences(of: sourceURL.path, with: "")
            if relativePath.contains("__PROJECT_NAME__") {
                relativePath = relativePath.replacingOccurrences(of: "__PROJECT_NAME__", with: projectName)
            }
            
            let destinationItemURL = destinationURL.appendingPathComponent(relativePath)

            let isDirectory = (try? sourceItemURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false

            if isDirectory {
                try fileManager.createDirectory(at: destinationItemURL, withIntermediateDirectories: true, attributes: nil)
            } else {
                var content = try String(contentsOf: sourceItemURL, encoding: .utf8)
                content = content.replacingOccurrences(of: "__PROJECT_NAME__", with: projectName)
                try content.write(to: destinationItemURL, atomically: true, encoding: .utf8)
            }
        }
    }
}

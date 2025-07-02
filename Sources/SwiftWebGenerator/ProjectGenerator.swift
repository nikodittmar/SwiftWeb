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

    
    // In Sources/SwiftWebGenerator/ProjectGenerator.swift

    private func copyTemplate(from sourceURL: URL, to destinationURL: URL) throws {
        // Get the contents of the source directory
        let contents = try fileManager.contentsOfDirectory(at: sourceURL, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)
        
        // Create the destination directory
        try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
        
        // Loop through each item in the source directory
        for sourceItemURL in contents {
            // Create the destination path
            var destinationItemURL = destinationURL.appendingPathComponent(sourceItemURL.lastPathComponent)
            
            // --- This is the key part that handles renaming the __PROJECT_NAME__ folder ---
            if destinationItemURL.lastPathComponent.contains("__PROJECT_NAME__") {
                let newName = destinationItemURL.lastPathComponent.replacingOccurrences(of: "__PROJECT_NAME__", with: projectName)
                destinationItemURL.deleteLastPathComponent()
                destinationItemURL.appendPathComponent(newName)
            }

            // Check if the item is a directory
            let isDirectory = (try? sourceItemURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            
            if isDirectory {
                // If it's a directory, call this function again recursively
                try copyTemplate(from: sourceItemURL, to: destinationItemURL)
            } else {
                // If it's a file, read its content, replace the placeholder, and write it
                var content = try String(contentsOf: sourceItemURL, encoding: .utf8)
                content = content.replacingOccurrences(of: "__PROJECT_NAME__", with: projectName)
                try content.write(to: destinationItemURL, atomically: true, encoding: .utf8)
            }
        }
    }
}

public enum ProjectGeneratorError: Error {
    case failedToGetDirectory
}

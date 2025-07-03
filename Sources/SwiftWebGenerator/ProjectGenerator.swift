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
        let contents = try fileManager.contentsOfDirectory(at: sourceURL, includingPropertiesForKeys: [.isDirectoryKey], options: [])
        
        try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
        
        for sourceItemURL in contents {
            if sourceItemURL.lastPathComponent == ".DS_Store" {
                continue
            }

            var destinationItemURL = destinationURL.appendingPathComponent(sourceItemURL.lastPathComponent)
            
            if destinationItemURL.lastPathComponent.contains("__PROJECT_NAME__") {
                let newName = destinationItemURL.lastPathComponent.replacingOccurrences(of: "__PROJECT_NAME__", with: projectName)
                destinationItemURL.deleteLastPathComponent()
                destinationItemURL.appendPathComponent(newName)
            }

            let isDirectory = (try? sourceItemURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            
            if isDirectory {
                try copyTemplate(from: sourceItemURL, to: destinationItemURL)
            } else {
                let textFileExtensions = ["swift", "md", "json", "yml", "leaf"]
                let textFileNames = [".env", ".gitignore"]

                if textFileExtensions.contains(sourceItemURL.pathExtension) || textFileNames.contains(sourceItemURL.lastPathComponent) {
                    var content = try String(contentsOf: sourceItemURL, encoding: .utf8)
                    content = content.replacingOccurrences(of: "__PROJECT_NAME__", with: projectName)
                    content = content.replacingOccurrences(of: "__PROJECT_NAME_LOWERCASE__", with: projectName.lowercased())
                    content = content.replacingOccurrences(of: "__SYSTEM_USERNAME__", with: NSUserName())
                    try content.write(to: destinationItemURL, atomically: true, encoding: .utf8)
                } else {
                    try fileManager.copyItem(at: sourceItemURL, to: destinationItemURL)
                }
            }
        }
    }
}

public enum ProjectGeneratorError: Error {
    case failedToGetDirectory
}

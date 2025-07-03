//
//  GenerateCommand.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 7/2/25.
//
import ArgumentParser
import Foundation

struct GenerateCommand<T: ApplicationConfig>: ParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "generate",
            abstract: "Generates code.",
            subcommands: [
                
            ]
        )
    }
}

struct GenerateMigrationCommand<T: ApplicationConfig>: ParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "migration",
            abstract: "Generates a new migration file."
        )
    }
    
    @Argument(help: "The name of the migration.")
    var name: String
    
    func run() throws {
        print("[SwiftWeb] 🛠️ Generating migration: \(name)...")
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        let timestamp = dateFormatter.string(from: Date())

        let fileName = "\(timestamp)_\(name).swift"

        let migrationsDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Sources")
            .appendingPathComponent(T.projectName)
            .appendingPathComponent("Migrations")

        try FileManager.default.createDirectory(
            at: migrationsDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        let destinationURL = migrationsDirectory.appendingPathComponent(fileName)

        let fileContent = """
        import SwiftDB

        struct \(name): Migration {
            func up(db: Database) async throws {
                
            }

            func down(db: Database) async throws {

            }
        }
        """

        do { try fileContent.write(to: destinationURL, atomically: true, encoding: .utf8) } catch {
            print("[SwiftWeb] ❌ Error writing migration file: \(error)")
            return
        }

        let appConfigFileURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Sources/\(T.projectName)/main.swift")
        var fileContents = try String(contentsOf: appConfigFileURL, encoding: .utf8)

        let searchString = "static let migrations: [Migration.Type] = ["
        guard let range = fileContents.range(of: searchString) else {
            print("[SwiftWeb] ❌ Could not find `migrations` array in \(appConfigFileURL.path)")
            return
        }

        let stringToInsert = "\n        \(name).self,"

        fileContents.insert(contentsOf: stringToInsert, at: range.upperBound)

        do { try fileContents.write(to: appConfigFileURL, atomically: true, encoding: .utf8) } catch {
            print("[SwiftWeb] ❌ Error registering migration: \(error)")
            return
        }

        print("[SwiftWeb] ✅ Migration \(name) generated successfully!")
    }
}

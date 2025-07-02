//
//  Database.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 7/2/25.
//
import ArgumentParser

struct DatabaseCommand<T: ApplicationConfig>: ParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "db",
            abstract: "Manages the database.",
            subcommands: [MigrateCommand<T>.self]
        )
    }
}

struct MigrateCommand<T: ApplicationConfig>: ParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "migrate",
            abstract: "Runs any pending database migrations."
        )
    }
    
    func run() throws {
        print("⚙️ Running migrations...")
    }
}

//
//  DatabaseCommand.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 7/2/25.
//
import Foundation
import ArgumentParser
import NIO
import SwiftDB

struct DatabaseCommand<T: ApplicationConfig>: ParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "db",
            abstract: "Manages the database.",
            subcommands: [
                MigrateCommand<T>.self,
                CreateCommand<T>.self,
                DropCommand<T>.self,
                ResetCommand<T>.self
            ]
        )
    }
}

struct MigrateCommand<T: ApplicationConfig>: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "migrate",
            abstract: "Runs any pending database migrations."
        )
    }
    
    func run() async throws {
        print("[SwiftWeb] ⚙️ Running migrations...")

        do { try loadDotEnv(from: T.dotEnvPath) } catch {
            print("[SwiftWeb] ❌ Error loading .env file: \(error)")
            return
        }

        print("Loaded .env file successfully.")

        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

        print("event loop group created with \(System.coreCount) threads.")

        let db = try configureDatabase(eventLoopGroup: eventLoopGroup)

        print("Database configured successfully.")
    
        do {
            print("starting migrations")
            try await migrateDatabase(db: db, migrations: T.migrations)
            print("[SwiftWeb] ✅ Migrations completed successfully!")
        } catch {
            print("[SwiftWeb] ❌ Error running migrations: \(error)")
        } 

        print("Done!")

        Foundation.exit(0)
    }
}

struct CreateCommand<T: ApplicationConfig>: ParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "create",
            abstract: "Creates a new database.",
            discussion: "This command creates a new PostgreSQL database for the project."
        )
    }
    
    @Argument(help: "The name of the database to create. Defaults to the name in the .env file.")
    var dbName: String?
    
    func run() throws {
        print("[SwiftWeb] 🐘 Creating PostgreSQL database...")

        do { try loadDotEnv(from: T.dotEnvPath) } catch {
            print("[SwiftWeb] ❌ Error loading .env file: \(error)")
            return
        }

        guard let dbName = self.dbName ?? ProcessInfo.processInfo.environment["DATABASE_NAME"] else {
            print("[SwiftWeb] ❌ Error: Database name not provided and not found in .env file.")
            return
        }

        let commandOutput = try shell("createdb \(dbName)")

        if commandOutput.contains("already exists") {
            print("[SwiftWeb] ⚠️ Database '\(dbName)' already exists. Skipping creation.")
        } else {
            print("[SwiftWeb] ✅ Database '\(dbName)' created successfully!")
        }
    }
}

struct DropCommand<T: ApplicationConfig>: ParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "drop",
            abstract: "Drops the existing database.",
            discussion: "This command drops the PostgreSQL database for the project."
        )
    }
    
    func run() throws {
        print("[SwiftWeb] 🚫 Dropping PostgreSQL database...")

        do { try loadDotEnv(from: T.dotEnvPath) } catch {
            print("[SwiftWeb] ❌ Error loading .env file: \(error)")
            return
        }

        guard let dbName = ProcessInfo.processInfo.environment["DATABASE_NAME"] else {
            print("[SwiftWeb] ❌ Error: Database name not found in .env file.")
            return
        }

        let commandOutput = try shell("dropdb \(dbName)")

        if commandOutput.contains("does not exist") {
            print("[SwiftWeb] ⚠️ Database '\(dbName)' does not exist. Skipping drop.")
        } else {
            print("[SwiftWeb] ✅ Database '\(dbName)' dropped successfully!")
        }
    }
}

struct ResetCommand<T: ApplicationConfig>: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "reset",
            abstract: "Resets the database by dropping and recreating it.",
            discussion: "This command drops the existing database and creates a new one."
        )
    }
    
    func run() async throws {
        print("[SwiftWeb] 🔄 Resetting PostgreSQL database...")

        do { try loadDotEnv(from: T.dotEnvPath) } catch {
            print("[SwiftWeb] ❌ Error loading .env file: \(error)")
            return
        }

        guard let dbName = ProcessInfo.processInfo.environment["DATABASE_NAME"] else {
            print("[SwiftWeb] ❌ Error: Database name not found in .env file.")
            return
        }

        _ = try shell("dropdb \(dbName)")
        _ = try shell("createdb \(dbName)")

        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

        let db = try configureDatabase(eventLoopGroup: eventLoopGroup)

        do {
            try await migrateDatabase(db: db, migrations: T.migrations)
            print("[SwiftWeb] ✅ Database '\(dbName)' reset successfully!")
        } catch {
            print("[SwiftWeb] ❌ Error resetting database: \(error)")
        }

        Foundation.exit(0)
    }
}
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

struct DatabaseCommand<T: SwiftWebConfig>: ParsableCommand {
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

struct MigrateCommand<T: SwiftWebConfig>: AsyncParsableCommand {
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

        let eventLoopGroup: MultiThreadedEventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    
        do {
            let db = try await Database.connect(
                config: getDatabaseConfig(),
                eventLoopGroup: eventLoopGroup
            )
            try await db.migrate(T.migrations)
            print("[SwiftWeb] ✅ Migrations completed successfully!")
        } catch {
            print("[SwiftWeb] ❌ Error running migrations: \(error)")
        } 
    }
}

struct CreateCommand<T: SwiftWebConfig>: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "create",
            abstract: "Creates a new database.",
            discussion: "This command creates a new PostgreSQL database for the project."
        )
    }
    
    @Argument(help: "The name of the database to create. Defaults to the name in the .env file.")
    var name: String?
    
    func run() async throws {
        print("[SwiftWeb] 🐘 Creating PostgreSQL database...")

        do { try loadDotEnv(from: T.dotEnvPath) } catch {
            print("[SwiftWeb] ❌ Error loading .env file: \(error)")
            return
        }

        guard let name = self.name ?? ProcessInfo.processInfo.environment["DATABASE_NAME"] else {
            print("[SwiftWeb] ❌ Error: Database name not provided and not found in .env file.")
            return
        }

        let eventLoopGroup: MultiThreadedEventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

        do {
            _ = try await Database.create(name: name, maintenanceConfig: getMaintenenceDatabaseConfig(), eventLoopGroup: eventLoopGroup)
            print("[SwiftWeb] ✅ Database '\(name)' created successfully!")
        } catch {
            print("[SwiftWeb] ❌ Failed to create database '\(name)': \(error)")
        }
    }
}

struct DropCommand<T: SwiftWebConfig>: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "drop",
            abstract: "Drops the existing database.",
            discussion: "This command drops the PostgreSQL database for the project."
        )
    }
    
    func run() async throws {
        print("[SwiftWeb] 🚫 Dropping PostgreSQL database...")

                do { try loadDotEnv(from: T.dotEnvPath) } catch {
            print("[SwiftWeb] ❌ Error loading .env file: \(error)")
            return
        }

        guard let name = ProcessInfo.processInfo.environment["DATABASE_NAME"] else {
            print("[SwiftWeb] ❌ Error: Database name not provided and not found in .env file.")
            return
        }

        let eventLoopGroup: MultiThreadedEventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

        do {
            _ = try await Database.create(name: name, maintenanceConfig: getMaintenenceDatabaseConfig(), eventLoopGroup: eventLoopGroup)
            print("[SwiftWeb] ✅ Database '\(name)' dropped successfully!")
        } catch {
            print("[SwiftWeb] ❌ Failed to drop database '\(name)': \(error)")
        }
    }
}

struct ResetCommand<T: SwiftWebConfig>: AsyncParsableCommand {
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

        guard let name = ProcessInfo.processInfo.environment["DATABASE_NAME"] else {
            print("[SwiftWeb] ❌ Error: Database name not provided and not found in .env file.")
            return
        }

        let eventLoopGroup: MultiThreadedEventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

        do {
            print("[SwiftWeb] 🚫 Dropping PostgreSQL database...")
            try await Database.drop(name: name, maintenanceConfig: getMaintenenceDatabaseConfig(), eventLoopGroup: eventLoopGroup)
            print("[SwiftWeb] ✅ Database '\(name)' dropped successfully!")
            print("[SwiftWeb] 🐘 Creating PostgreSQL database...")
            let db = try await Database.create(name: name, maintenanceConfig: getMaintenenceDatabaseConfig(), eventLoopGroup: eventLoopGroup)
            print("[SwiftWeb] ✅ Database '\(name)' created successfully!")
            print("[SwiftWeb] ⚙️ Running migrations...")
            try await db.migrate(T.migrations)
            print("[SwiftWeb] ✅ Migrations applied successfully!")
        } catch {
            print("[SwiftWeb] ❌ Failed to reset database '\(name)': \(error)")
        }
    }
}

func getDatabaseConfig() throws -> DatabaseConfig {
    guard let dbName = ProcessInfo.processInfo.environment["DATABASE_NAME"] else {
        print("[SwiftWeb] ❌ Error: Database name not found in .env file.")
        throw GetDatabaseError.missingDatabaseName
    }

    guard let username = ProcessInfo.processInfo.environment["DATABASE_USER"] else {
        print("[SwiftWeb] ❌ Error: Database username not found in .env file.")
        throw GetDatabaseError.missingDatabaseUser
    }

    guard let host = ProcessInfo.processInfo.environment["DATABASE_HOST"] else {
        print("[SwiftWeb] ❌ Error: Database host not found in .env file.")
        throw GetDatabaseError.missingDatabaseHost
    }

    let port: Int = Int(ProcessInfo.processInfo.environment["DATABASE_PORT"] ?? "5432")!

    var password = ProcessInfo.processInfo.environment["DATABASE_PASSWORD"]

    if password == "" {
        password = nil
    }

    let config = DatabaseConfig(
        host: host,
        port: port,
        username: username,
        password: password,
        database: dbName
    )

    return config
}

func getMaintenenceDatabaseConfig() throws -> DatabaseConfig {
    guard let dbName = ProcessInfo.processInfo.environment["MAINTENENCE_DATABASE_NAME"] else {
        print("[SwiftWeb] ❌ Error: Database name not found in .env file.")
        throw GetDatabaseError.missingDatabaseName
    }

    guard let username = ProcessInfo.processInfo.environment["DATABASE_USER"] else {
        print("[SwiftWeb] ❌ Error: Database username not found in .env file.")
        throw GetDatabaseError.missingDatabaseUser
    }

    guard let host = ProcessInfo.processInfo.environment["DATABASE_HOST"] else {
        print("[SwiftWeb] ❌ Error: Database host not found in .env file.")
        throw GetDatabaseError.missingDatabaseHost
    }

    let port: Int = Int(ProcessInfo.processInfo.environment["DATABASE_PORT"] ?? "5432")!

    var password = ProcessInfo.processInfo.environment["DATABASE_PASSWORD"]

    if password == "" {
        password = nil
    }

    let config = DatabaseConfig(
        host: host,
        port: port,
        username: username,
        password: password,
        database: dbName
    )

    return config
}

enum GetDatabaseError: Error {
    case missingDatabaseName
    case missingDatabaseUser
    case missingDatabaseHost
    case missingDatabasePort
}


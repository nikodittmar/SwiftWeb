//
//  Database.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 7/2/25.
//
import SwiftDB
import NIO
import Foundation

func configureDatabase(eventLoopGroup: MultiThreadedEventLoopGroup) throws -> Database {
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

    var password = ProcessInfo.processInfo.environment["DATABASE_PASSWORD"]

    if password == "" {
        password = nil
    }

    let config = DatabaseConfig(
        database: dbName,
        username: username,
        password: password,
        host: host
    )

    let db = Database(config: config, eventLoopGroup: eventLoopGroup)

    return db
}

func migrateDatabase(db: Database, migrations: [Migration.Type]) async throws {
    let migrationRunner = MigrationRunner(db: db, migrations: migrations)

    try await migrationRunner.run()
}

enum GetDatabaseError: Error {
    case missingDatabaseName
    case missingDatabaseUser
    case missingDatabaseHost
}
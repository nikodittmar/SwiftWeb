//
//  DatabaseTestHelpers.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 7/17/25.
//

import Foundation
import NIO
import SwiftDB
import PostgresNIO

enum DatabaseTestHelpers {

    static let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)

    static let testHost = ProcessInfo.processInfo.environment["TEST_DATABASE_HOST"] ?? "localhost"
    static let testPort = Int(ProcessInfo.processInfo.environment["TEST_DATABASE_PORT"] ?? "5432")!
    static let testUsername = ProcessInfo.processInfo.environment["TEST_DATABASE_USERNAME"] ?? "test_username"
    static let testPassword = ProcessInfo.processInfo.environment["TEST_DATABASE_PASSWORD"] ?? "test_password"
    static let testDatabase = ProcessInfo.processInfo.environment["TEST_DATABASE_NAME"] ?? "test_database"

    static let healthyDatabaseConfig = DatabaseConfig(
        host: testHost,
        port: testPort,
        username: testUsername,
        password: testPassword,
        database: testDatabase,
        tls: .disable
    )

    static let unhealthyConfig = DatabaseConfig(
        host: "192.0.2.1", // Unreachable IP address
        port: 9999, 
        username: testUsername,
        password: testPassword,
        database: testDatabase,
        tls: .disable
    )

    static func uniqueDatabaseName() -> String {
        return "test_database_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
    }

    static func cleanup(dbName: String) {
        Task {
            try? await Database.drop(name: dbName, maintenanceConfig: healthyDatabaseConfig, eventLoopGroup: eventLoopGroup)
        }
    }

    /// IMPORTANT: tests that use this helper method MUST RUN IN SERIAL!!
    static func testDatabase() async throws -> Database {
        let db = try await Database.connect(
            config: healthyDatabaseConfig,
            eventLoopGroup: eventLoopGroup
        )

        let rows = try await db.query("""
            SELECT table_name
            FROM information_schema.tables
            WHERE table_schema = 'public'
        """).collect()
        
        let tableNames = try rows.map { try $0.decode(String.self) }

        if !tableNames.isEmpty {
            let tablesSql = tableNames.map { "\"\($0)\"" }.joined(separator: ", ")
            let dropQuery = "DROP TABLE \(tablesSql) CASCADE;"

            _ = try await db.query(PostgresQuery(stringLiteral: dropQuery))
        }
        
        return db
    }
}
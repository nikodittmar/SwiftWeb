//
//  DatabaseTestHelpers.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 7/17/25.
//

import Foundation
import NIO
import SwiftDB

enum DatabaseTestHelpers {

    static let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)

    static let testHost = ProcessInfo.processInfo.environment["TEST_DB_HOST"] ?? "localhost"
    static let testPort = Int(ProcessInfo.processInfo.environment["TEST_DB_PORT"] ?? "5432")!
    static let testUsername = ProcessInfo.processInfo.environment["TEST_DB_USERNAME"] ?? "test_username"
    static let testPassword = ProcessInfo.processInfo.environment["TEST_DB_PASSWORD"] ?? "test_password"
    static let testDatabase = ProcessInfo.processInfo.environment["TEST_DB_DATABASE"] ?? "test_database"

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
}
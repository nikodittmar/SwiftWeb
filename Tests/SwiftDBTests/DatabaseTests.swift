//
//  DatabaseTests.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 7/5/25.
//
import Foundation
import Testing
import NIO
@testable import SwiftDB

@Suite struct DatabaseTests {
    
    let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        
    let healthyConfig: DatabaseConfig
    let unhealthyConfig: DatabaseConfig
    
    init() {
        let host = ProcessInfo.processInfo.environment["TEST_DB_HOST"] ?? "localhost"
        let port = Int(ProcessInfo.processInfo.environment["TEST_DB_PORT"] ?? "5432")!
        let username = ProcessInfo.processInfo.environment["TEST_DB_USERNAME"] ?? "test_username"
        let password = ProcessInfo.processInfo.environment["TEST_DB_PASSWORD"] ?? "test_password"
        let database = ProcessInfo.processInfo.environment["TEST_DB_DATABASE"] ?? "test_database"
        
        self.healthyConfig = DatabaseConfig(
            host: host,
            port: port,
            username: username,
            password: password,
            database: database,
            tls: false
        )
        
        self.unhealthyConfig = DatabaseConfig(
            host: "192.0.2.1",
            port: 9999, 
            username: username,
            password: password,
            database: database,
            tls: false
        )
    }

    func databaseName() -> String {
        return "test_database_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
    }
    
    @Test func test_Database_ConnectToExistentDatabase_IsValid() async throws {
        let db = try await Database.connect(config: healthyConfig, eventLoopGroup: eventLoopGroup)
        db.shutdown()
    }
    
    @Test func test_Database_ConnectToUnreachableHost_Fails() async {
        await #expect(throws: DatabaseError.self) {
            try await Database.connect(config: unhealthyConfig, eventLoopGroup: eventLoopGroup)
        }
    }

    @Test func test_Database_ConnectToNonexistentDatabase_Fails() async {
        var config = healthyConfig
        config.database = databaseName()
        
        await #expect(throws: DatabaseError.self) {
            try await Database.connect(config: config, eventLoopGroup: eventLoopGroup)
        }
    }

    @Test func test_Database_CreateAndDropDatabase_IsValid() async throws {
        let newDBName = databaseName()

        let createdDB = try await Database.create(name: newDBName, maintenanceConfig: healthyConfig, eventLoopGroup: eventLoopGroup)
        createdDB.shutdown()

        await #expect(throws: DatabaseError.self) {
            try await Database.create(name: newDBName, maintenanceConfig: healthyConfig, eventLoopGroup: eventLoopGroup)
        }

        var newDBConfig = healthyConfig
        newDBConfig.database = newDBName

        let connectedDB = try await Database.connect(config: newDBConfig, eventLoopGroup: eventLoopGroup)
        connectedDB.shutdown()

        try await Database.drop(name: newDBName, maintenanceConfig: healthyConfig, eventLoopGroup: eventLoopGroup)

        await #expect(throws: DatabaseError.self) {
            try await Database.connect(config: newDBConfig, eventLoopGroup: eventLoopGroup)
        }
    }
}

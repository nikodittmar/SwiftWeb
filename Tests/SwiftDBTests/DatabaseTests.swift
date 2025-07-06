//
//  DatabaseTests.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 7/5/25.
//
import Foundation
import NIO
import Testing
@testable import SwiftDB

@Suite("Database Tests")
struct DatabaseTests {
    
    let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        
    let healthyConfig: DatabaseConfig
    let unhealthyConfig: DatabaseConfig
    
    init() {
        let host = ProcessInfo.processInfo.environment["TEST_DB_HOST"] ?? "localhost"
        let port = Int(ProcessInfo.processInfo.environment["TEST_DB_PORT"] ?? "5432")!
        let username = ProcessInfo.processInfo.environment["TEST_DB_USERNAME"] ?? NSUserName()
        let password = ProcessInfo.processInfo.environment["TEST_DB_PASSWORD"]
        let database = ProcessInfo.processInfo.environment["TEST_DB_DATABASE"] ?? "postgres"
        
        self.healthyConfig = DatabaseConfig(
            host: host,
            port: port,
            username: username,
            password: password,
            database: database
        )
        
        self.unhealthyConfig = DatabaseConfig(
            host: "192.0.2.1",
            port: port,
            username: username,
            password: password,
            database: database
        )
    }
    
    @Test func test_Database_ConnectToExistentDatabase_IsValid() async throws {
        _ = try await Database.connect(config: healthyConfig, eventLoopGroup: eventLoopGroup)
    }
    
    @Test func test_Database_ConnectToNonexistentDatabase_IsValid() async {
        await #expect(throws: DatabaseError.connectionFailed) {
            try await Database.connect(config: unhealthyConfig, eventLoopGroup: eventLoopGroup)
        }
    }
}

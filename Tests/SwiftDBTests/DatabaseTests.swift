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

@Suite struct DatabaseTests {
    
    @Test func test_Database_ConnectToExistentDatabase_IsValid() async throws {
        let db = try await Database.connect(config: DatabaseTestHelpers.healthyDatabaseConfig, eventLoopGroup: DatabaseTestHelpers.eventLoopGroup)
        db.shutdown()
    }
    
    @Test func test_Database_ConnectToUnreachableHost_Fails() async {
        await #expect(throws: DatabaseError.self) {
            try await Database.connect(config: DatabaseTestHelpers.unhealthyConfig, eventLoopGroup: DatabaseTestHelpers.eventLoopGroup)
        }
    }

    @Test func test_Database_ConnectToNonexistentDatabase_Fails() async {
        var config = DatabaseTestHelpers.healthyDatabaseConfig
        config.database = DatabaseTestHelpers.uniqueDatabaseName()
        
        await #expect(throws: DatabaseError.self) {
            try await Database.connect(config: config, eventLoopGroup: DatabaseTestHelpers.eventLoopGroup)
        }
    }

    @Test func test_Database_CreateAndDropDatabase_IsValid() async throws {
        let newDBName = DatabaseTestHelpers.uniqueDatabaseName()

        let createdDB = try await Database.create(name: newDBName, maintenanceConfig: DatabaseTestHelpers.healthyDatabaseConfig, eventLoopGroup: DatabaseTestHelpers.eventLoopGroup)
        createdDB.shutdown()

        await #expect(throws: DatabaseError.self) {
            try await Database.create(name: newDBName, maintenanceConfig: DatabaseTestHelpers.healthyDatabaseConfig, eventLoopGroup: DatabaseTestHelpers.eventLoopGroup)
        }

        var newDBConfig = DatabaseTestHelpers.healthyDatabaseConfig
        newDBConfig.database = newDBName

        let connectedDB = try await Database.connect(config: newDBConfig, eventLoopGroup: DatabaseTestHelpers.eventLoopGroup)
        connectedDB.shutdown()

        try await Database.drop(name: newDBName, maintenanceConfig: DatabaseTestHelpers.healthyDatabaseConfig, eventLoopGroup: DatabaseTestHelpers.eventLoopGroup)

        await #expect(throws: DatabaseError.self) {
            try await Database.connect(config: newDBConfig, eventLoopGroup: DatabaseTestHelpers.eventLoopGroup)
        }
    }

    @Test func test_Database_CreateWithInvalidName_ThrowsError() async throws {
        let invalidName = "invalid-db-name"
        
        await #expect(throws: DatabaseError.self) {
            _ = try await Database.create(name: invalidName, maintenanceConfig: DatabaseTestHelpers.healthyDatabaseConfig, eventLoopGroup: DatabaseTestHelpers.eventLoopGroup)
        }
    }

    @Test func test_Database_Reset_IsValid() async throws {
        let maintenanceConfig = DatabaseTestHelpers.healthyDatabaseConfig

        let dbName = DatabaseTestHelpers.uniqueDatabaseName()
        var config = DatabaseTestHelpers.healthyDatabaseConfig
        config.database = dbName
        
        let initialDB = try await Database.create(name: dbName, maintenanceConfig: maintenanceConfig, eventLoopGroup: DatabaseTestHelpers.eventLoopGroup)
        defer { DatabaseTestHelpers.cleanup(dbName: dbName) }
        initialDB.shutdown()

        let resetDB = try await Database.reset(name: dbName, maintenanceConfig: maintenanceConfig, eventLoopGroup: DatabaseTestHelpers.eventLoopGroup)
        resetDB.shutdown()

        let connectedDB = try await Database.connect(config: config, eventLoopGroup: DatabaseTestHelpers.eventLoopGroup)
        connectedDB.shutdown()
    }

    @Test func test_Database_Query_IsValid() async throws {
        let maintenanceConfig = DatabaseTestHelpers.healthyDatabaseConfig

        let dbName = DatabaseTestHelpers.uniqueDatabaseName()
        let db = try await Database.create(name: dbName, maintenanceConfig: maintenanceConfig, eventLoopGroup: DatabaseTestHelpers.eventLoopGroup)
        defer {
            db.shutdown()
            DatabaseTestHelpers.cleanup(dbName: dbName)
        }
        
        _ = try await db.query("""
            CREATE TABLE IF NOT EXISTS "posts" (
                id SERIAL PRIMARY KEY,
                title TEXT,
                author TEXT,
                likes INTEGER
            )
        """)

        let post_title = "Swift on Server!"
        let post_author = "John Appleseed"
        let post_likes = 1234

        _ = try await db.query("""
            INSERT INTO "posts" (title, author, likes)
                VALUES
                    (\(post_title), \(post_author), \(post_likes))
        """)

        guard let row = try await db.query("""
            SELECT id, title, author, likes FROM "posts" WHERE title = \(post_title)
        """).collect().first else {
            Issue.record("Expected to receive a row.")
            return
        }

        guard let (query_id, query_title, query_author, query_likes) = try? row.decode((Int, String, String, Int).self) else {
            Issue.record("Expected to decode row.")
            return
        }

        #expect(query_id == 1)
        #expect(post_title == query_title)
        #expect(post_author == query_author)
        #expect(post_likes == query_likes)
    }
}

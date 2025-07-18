//
//  MigrationTests.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 7/3/25.
//

import Testing
import NIO
import PostgresNIO
@testable import SwiftDB

@Suite struct MigrationTests {

    struct Migration_1: Migration {
        static let name: String = "1_Create_Books_Table"

        static func up(on connection: PostgresConnection) async throws {
            _ = try await connection.query("""
                CREATE TABLE IF NOT EXISTS "books" (
                    id SERIAL PRIMARY KEY,
                    title TEXT
                )
            """).get()
        }

        static func down(on connection: PostgresConnection) async throws {
            _ = try await connection.query("""
                DROP TABLE IF EXISTS "books"
            """).get()
        }
    }

    struct Migration_2: Migration {
        static let name: String = "2_Add_Author_To_Books"

        static func up(on connection: PostgresConnection) async throws {
            _ = try await connection.query("""
                ALTER TABLE IF EXISTS "books"
                    ADD COLUMN IF NOT EXISTS author TEXT
            """).get()
        }

        static func down(on connection: PostgresConnection) async throws {
                _ = try await connection.query("""
                ALTER TABLE IF EXISTS "books"
                    DROP COLUMN IF EXISTS author
            """).get()
        }
    }
    
    @Test func test_Database_SimpleMigrate_IsValid() async throws {
        let migrations: [Migration.Type] = [Migration_1.self]

        let dbName = DatabaseTestHelpers.uniqueDatabaseName()
        let db = try await Database.create(name: dbName, maintenanceConfig: DatabaseTestHelpers.healthyDatabaseConfig, eventLoopGroup: DatabaseTestHelpers.eventLoopGroup)
        defer { DatabaseTestHelpers.cleanup(dbName: dbName) }

        try await db.migrate(migrations)

        let rows = try await db.query("""
            SELECT column_name FROM information_schema.columns WHERE table_name = 'books'
        """).collect()

        #expect(rows.count == 2)
    }

    @Test func test_Database_MultipleMigrations_IsValid() async throws {
        let migrations: [Migration.Type] = [Migration_1.self, Migration_2.self]
        
        let dbName = DatabaseTestHelpers.uniqueDatabaseName()
        let db = try await Database.create(name: dbName, maintenanceConfig: DatabaseTestHelpers.healthyDatabaseConfig, eventLoopGroup: DatabaseTestHelpers.eventLoopGroup)
        defer { DatabaseTestHelpers.cleanup(dbName: dbName) }

        try await db.migrate(migrations)

        let rows = try await db.query("""
            SELECT column_name FROM information_schema.columns WHERE table_name = 'books'
        """).collect()

        #expect(rows.count == 3)
    }

    @Test func test_Database_MigrationAlreadyRun_IsValid() async throws {
        let migration_batch_1: [Migration.Type] = [Migration_1.self]
        let migration_batch_2: [Migration.Type] = [Migration_1.self, Migration_2.self]

        let dbName = DatabaseTestHelpers.uniqueDatabaseName()
        let db = try await Database.create(name: dbName, maintenanceConfig: DatabaseTestHelpers.healthyDatabaseConfig, eventLoopGroup: DatabaseTestHelpers.eventLoopGroup)
        defer { DatabaseTestHelpers.cleanup(dbName: dbName) }
        try await db.migrate(migration_batch_1)

        let rows_before = try await db.query("""
            SELECT column_name FROM information_schema.columns WHERE table_name = 'books'
        """).collect()

        #expect(rows_before.count == 2)

        try await db.migrate(migration_batch_2)

        let rows_after = try await db.query("""
            SELECT column_name FROM information_schema.columns WHERE table_name = 'books'
        """).collect()

        #expect(rows_after.count == 3)

    }

    @Test func test_Database_RollbackSimpleMigration_IsValid() async throws  {
        let migrations: [Migration.Type] = [Migration_1.self]

        let dbName = DatabaseTestHelpers.uniqueDatabaseName()
        let db = try await Database.create(name: dbName, maintenanceConfig: DatabaseTestHelpers.healthyDatabaseConfig, eventLoopGroup: DatabaseTestHelpers.eventLoopGroup)
        defer { DatabaseTestHelpers.cleanup(dbName: dbName) }

        try await db.migrate(migrations)
        try await db.rollback(migrations, step: 1)

        let rows = try await db.query("""
            SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'books'
        """).collect()

        #expect(rows.isEmpty)
    }

    @Test func test_Database_RollbackMultipleRanMigrations_IsValid() async throws  {
        let migrations: [Migration.Type] = [Migration_1.self, Migration_2.self]
        
        let dbName = DatabaseTestHelpers.uniqueDatabaseName()
        let db = try await Database.create(name: dbName, maintenanceConfig: DatabaseTestHelpers.healthyDatabaseConfig, eventLoopGroup: DatabaseTestHelpers.eventLoopGroup)
        defer { DatabaseTestHelpers.cleanup(dbName: dbName) }

        try await db.migrate(migrations)
        try await db.rollback(migrations, step: 1)

        let rows = try await db.query("""
            SELECT column_name FROM information_schema.columns WHERE table_name = 'books'
        """).collect()

        #expect(rows.count == 2)
    }

    @Test func test_Database_RollbackMultipleMigrations_IsValid() async throws  {
        let migrations: [Migration.Type] = [Migration_1.self, Migration_2.self]
        
        let dbName = DatabaseTestHelpers.uniqueDatabaseName()
        let db = try await Database.create(name: dbName, maintenanceConfig: DatabaseTestHelpers.healthyDatabaseConfig, eventLoopGroup: DatabaseTestHelpers.eventLoopGroup)
        defer { DatabaseTestHelpers.cleanup(dbName: dbName) }

        try await db.migrate(migrations)
        try await db.rollback(migrations, step: 2)

        let rows = try await db.query("""
            SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'books'
        """).collect()

        #expect(rows.isEmpty)
    }

    @Test func test_Database_MissingRollbackMigration_Throws() async throws  {
        let migrations_full: [Migration.Type] = [Migration_1.self, Migration_2.self]
        let migrations_missing: [Migration.Type] = [Migration_1.self]

        let dbName = DatabaseTestHelpers.uniqueDatabaseName()
        let db = try await Database.create(name: dbName, maintenanceConfig: DatabaseTestHelpers.healthyDatabaseConfig, eventLoopGroup: DatabaseTestHelpers.eventLoopGroup)
        defer { DatabaseTestHelpers.cleanup(dbName: dbName) }
        
        try await db.migrate(migrations_full)
        await #expect(throws: DatabaseError.self) {
            try await db.rollback(migrations_missing, step: 2)
        }
    }

    @Test func test_Database_RollbackInvalidStep_Throws() async throws  {
        let migrations: [Migration.Type] = [Migration_1.self, Migration_2.self]

        let dbName = DatabaseTestHelpers.uniqueDatabaseName()
        let db = try await Database.create(name: dbName, maintenanceConfig: DatabaseTestHelpers.healthyDatabaseConfig, eventLoopGroup: DatabaseTestHelpers.eventLoopGroup)
        defer { DatabaseTestHelpers.cleanup(dbName: dbName) }
        
        try await db.migrate(migrations)
        await #expect(throws: DatabaseError.self) {
            try await db.rollback(migrations, step: 0)
        }
    }

}
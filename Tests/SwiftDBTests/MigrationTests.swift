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

@Suite class MigrationTests {

    struct Migration_1: ExplicitMigration {
        static let name: String = "20250718102456_CreateBooksTable"

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

    struct Migration_2: ExplicitMigration {
        static let name: String = "20250718105812_AddAuthorToBooks"

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

    let dbName: String
    let db: Database

    init() async throws {
        self.dbName = DatabaseTestHelpers.uniqueDatabaseName()
        self.db = try await Database.create(name: self.dbName, maintenanceConfig: DatabaseTestHelpers.maintenanceConfig, eventLoopGroup: DatabaseTestHelpers.eventLoopGroup)
    }

    deinit {
        self.db.shutdown()
        let name = self.dbName
        Task {
            try await Database.drop(name: name, maintenanceConfig: DatabaseTestHelpers.maintenanceConfig, eventLoopGroup: DatabaseTestHelpers.eventLoopGroup)
        }
    }
    
    @Test func test_Database_SimpleMigrate_IsValid() async throws {
        let migrations: [ExplicitMigration.Type] = [Migration_1.self]

        try await self.db.migrate(migrations)

        let rows = try await self.db.query("""
            SELECT column_name FROM information_schema.columns WHERE table_name = 'books'
        """).collect()

        #expect(rows.count == 2)
    }

    @Test func test_Database_MultipleMigrations_IsValid() async throws {
        let migrations: [ExplicitMigration.Type] = [Migration_1.self, Migration_2.self]

        try await self.db.migrate(migrations)

        let rows = try await self.db.query("""
            SELECT column_name FROM information_schema.columns WHERE table_name = 'books'
        """).collect()

        #expect(rows.count == 3)
    }

    @Test func test_Database_MigrationAlreadyRun_IsValid() async throws {
        let migration_batch_1: [ExplicitMigration.Type] = [Migration_1.self]
        let migration_batch_2: [ExplicitMigration.Type] = [Migration_1.self, Migration_2.self]

        try await self.db.migrate(migration_batch_1)

        let rows_before: [PostgresRow] = try await self.db.query("""
            SELECT column_name FROM information_schema.columns WHERE table_name = 'books'
        """).collect()

        #expect(rows_before.count == 2)

        try await self.db.migrate(migration_batch_2)

        let rows_after = try await self.db.query("""
            SELECT column_name FROM information_schema.columns WHERE table_name = 'books'
        """).collect()

        #expect(rows_after.count == 3)

    }

    @Test func test_Database_RollbackSimpleMigration_IsValid() async throws  {
        let migrations: [ExplicitMigration.Type] = [Migration_1.self]

        try await self.db.migrate(migrations)
        try await self.db.rollback(migrations, step: 1)

        let rows = try await db.query("""
            SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'books'
        """).collect()

        #expect(rows.isEmpty)
    }

    @Test func test_Database_RollbackMultipleRanMigrations_IsValid() async throws  {
        let migrations: [ExplicitMigration.Type] = [Migration_1.self, Migration_2.self]

        try await self.db.migrate(migrations)
        try await self.db.rollback(migrations, step: 1)

        let rows = try await db.query("""
            SELECT column_name FROM information_schema.columns WHERE table_name = 'books'
        """).collect()

        #expect(rows.count == 2)
    }

    @Test func test_Database_RollbackMultipleMigrations_IsValid() async throws  {
        let migrations: [ExplicitMigration.Type] = [Migration_1.self, Migration_2.self]

        try await self.db.migrate(migrations)
        try await self.db.rollback(migrations, step: 2)

        let rows = try await self.db.query("""
            SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'books'
        """).collect()

        #expect(rows.isEmpty)
    }

    @Test func test_Database_MissingRollbackMigration_Throws() async throws  {
        let migrations_full: [ExplicitMigration.Type] = [Migration_1.self, Migration_2.self]
        let migrations_missing: [ExplicitMigration.Type] = [Migration_1.self]
        
        try await self.db.migrate(migrations_full)
        await #expect(throws: DatabaseError.self) {
            try await self.db.rollback(migrations_missing, step: 2)
        }
    }

    @Test func test_Database_RollbackInvalidStep_Throws() async throws  {
        let migrations: [ExplicitMigration.Type] = [Migration_1.self, Migration_2.self]
        
        try await self.db.migrate(migrations)
        await #expect(throws: DatabaseError.self) {
            try await self.db.rollback(migrations, step: 0)
        }
    }

    @Test func test_Database_InvalidMigration_ThrowsError() async throws {
        struct InvalidMigration: ExplicitMigration {
            static let name: String = "20250718105812_InvalidMigration"

            static func up(on connection: PostgresConnection) async throws {
                _ = try await connection.query("""
                    ALTER TABLE "books"
                        ADD COLUMN author TEXT
                """).get()
            }

            static func down(on connection: PostgresConnection) async throws {
                    _ = try await connection.query("""
                    ALTER TABLE "books"
                        DROP COLUMN author
                """).get()
            }
        }

        let migrations: [ExplicitMigration.Type] = [InvalidMigration.self]
        
        await #expect(throws: DatabaseError.self) {
            try await self.db.migrate(migrations)
        }
    }

}
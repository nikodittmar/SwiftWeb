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

    struct Migration_WithIndexes: Migration {
        static let name: String = "20250818174500_CreateUsersWithIndexes"

        static func change(builder: SchemaBuilder) {
            builder.createTable("users") { t in
                t.column("email", type: "text NOT NULL")
                t.column("username", type: "text NOT NULL")
            }
            builder.addIndex(on: "users", columns: ["email"], isUnique: true)
            builder.addIndex(on: "users", columns: ["username"])
        }
    }

    private struct PGIndex: Equatable {
        let name: String
        let isUnique: Bool
    }

    private func getIndexes(for table: String, on db: Database) async throws -> [PGIndex] {
        let query = """
            SELECT indexname, indexdef
            FROM pg_indexes
            WHERE schemaname = 'public' AND tablename = '\(table)'
        """
        let rows = try await db.query(PostgresQuery(unsafeSQL: query)).collect()

        return rows.compactMap { row -> PGIndex? in
            let randomAccessRow = row.makeRandomAccess()
            
            guard let name = try? randomAccessRow["indexname"].decode(String.self),
                  let definition = try? randomAccessRow["indexdef"].decode(String.self) else {
                return nil
            }
            
            return PGIndex(name: name, isUnique: definition.contains("UNIQUE"))
        }
    }
    
    private func getTables(on db: Database) async throws -> [String] {
        let query = "SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename NOT LIKE 'pg_%' AND tablename NOT LIKE 'sql_%'"
        let rows = try await db.query(PostgresQuery(unsafeSQL: query)).collect()
        
        return rows.compactMap { row -> String? in
            let randomAccessRow = row.makeRandomAccess()

            return try? randomAccessRow["tablename"].decode(String.self)
        }
    }

    @Test("SchemaBuilder correctly creates tables and indexes")
    func test_SchemaBuilder_CreateIndex_IsValid() async throws {
        let migrations: [Migration.Type] = [Migration_WithIndexes.self]
        try await self.db.migrate(migrations)

        let indexes = try await getIndexes(for: "users", on: self.db)

        #expect(indexes.count == 3)

        let emailIndex = PGIndex(name: "idx_users_email", isUnique: true)
        #expect(indexes.contains(emailIndex))

        let usernameIndex = PGIndex(name: "idx_users_username", isUnique: false)
        #expect(indexes.contains(usernameIndex))
    }

    @Test("SchemaBuilder correctly rolls back tables and indexes")
    func test_SchemaBuilder_RollbackIndex_IsValid() async throws {
        let migrations: [Migration.Type] = [Migration_WithIndexes.self]

        try await self.db.migrate(migrations)

        let tablesBefore = try await getTables(on: self.db)
        #expect(tablesBefore.contains("users"))
        #expect(tablesBefore.contains("migrations"))

        try await self.db.rollback(migrations, step: 1)

        let tablesAfter = try await getTables(on: self.db)
        #expect(!tablesAfter.contains("users"))
        
        let indexesAfter = try await getIndexes(for: "users", on: self.db)
        #expect(indexesAfter.isEmpty)
    }
}
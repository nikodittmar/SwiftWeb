//
//  SchemaBuilderTests.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 7/18/25.
//

import Testing
import NIO
import PostgresNIO
@testable import SwiftDB

@Suite(.serialized) struct SchemaBuilderTests {
    
    @Test("CreateTable generates correct SQL")
    func test_SchemaBuilder_CreateTable_IsValid() throws {
        struct CreateBooksTable: Migration {
        
            static let name: String = "20250718094030_CreateBooksTable"
            static func change(builder: SchemaBuilder) {
                builder.createTable("books") { t in
                    t.column("author", type: .text, null: true)
                    t.column("title", type: .string(length: 255), null: false)
                }
            }
        }

        let expectedUp = """
        CREATE TABLE IF NOT EXISTS "books" ("id" SERIAL PRIMARY KEY, "author" TEXT, "title" VARCHAR(255) NOT NULL)
        """
        let expectedDown = """
        DROP TABLE IF EXISTS "books"
        """

        let testBuilder = SchemaBuilder()
        CreateBooksTable.change(builder: testBuilder)
        let action = try #require(testBuilder.actions.first)

        #expect(action.upSql() == expectedUp)
        #expect(action.downSql() == expectedDown)
    }

    @Test("DropTable generates correct reversible SQL")
    func test_SchemaBuilder_DropTable_IsValid() throws {
        struct DropBooksTable: Migration {
            static let name: String = "20250718101550_DropBooksTable"
            static func change(builder: SchemaBuilder) {
                builder.dropTable("books") { t in
                    t.column("author", type: .text)
                    t.column("title", type: .string(length: 255), null: false)
                }
            }
        }

        let expectedUp = """
        DROP TABLE IF EXISTS "books"
        """
        let expectedDown = """
        CREATE TABLE IF NOT EXISTS "books" ("id" SERIAL PRIMARY KEY, "author" TEXT, "title" VARCHAR(255) NOT NULL)
        """

        let testBuilder = SchemaBuilder()
        DropBooksTable.change(builder: testBuilder)
        let action = try #require(testBuilder.actions.first)

        #expect(action.upSql() == expectedUp)
        #expect(action.downSql() == expectedDown)
    }
    
    @Test("CreateTable with foreign key generates correct SQL")
    func test_SchemaBuilder_CreateTableWithForeignKey_IsValid() throws {
        struct CreatePostsTable: Migration {
            static let name = "20250818183000_CreatePostsTable"
            static func change(builder: SchemaBuilder) {
                builder.createTable("posts") { t in
                    t.column("title", type: .string, null: false)
                    t.references("users", null: false, onDelete: .cascade)
                }
            }
        }
        
        let expectedUp = """
        CREATE TABLE IF NOT EXISTS "posts" ("id" SERIAL PRIMARY KEY, "title" VARCHAR NOT NULL, "users_id" INTEGER NOT NULL, FOREIGN KEY ("users_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION)
        """
        let expectedDown = """
        DROP TABLE IF EXISTS "posts"
        """
        
        let testBuilder = SchemaBuilder()
        CreatePostsTable.change(builder: testBuilder)
        let action = try #require(testBuilder.actions.first)

        #expect(action.upSql() == expectedUp)
        #expect(action.downSql() == expectedDown)
    }

    @Test("AddColumn generates correct reversible SQL")
    func test_SchemaBuilder_AddColumn_IsValid() throws {
        struct AddLikesToPosts: Migration {
            static let name: String = "20250718102130_AddLikesToPosts"
            static func change(builder: SchemaBuilder) {
                builder.addColumn("likes", type: .integer, null: false, table: "posts")
            }
        }

        let expectedUp = """
        ALTER TABLE IF EXISTS "posts" ADD COLUMN "likes" INTEGER NOT NULL
        """
        let expectedDown = """
        ALTER TABLE IF EXISTS "posts" DROP COLUMN "likes"
        """

        let testBuilder = SchemaBuilder()
        AddLikesToPosts.change(builder: testBuilder)
        let action = try #require(testBuilder.actions.first)

        #expect(action.upSql() == expectedUp)
        #expect(action.downSql() == expectedDown)
    }

    @Test("DropColumn generates correct reversible SQL")
    func test_SchemaBuilder_DropColumn_IsValid() throws {
        struct RemoveLikesFromPosts: Migration {
            static let name: String = "20250718102512_RemoveLikesFromPosts"
            static func change(builder: SchemaBuilder) {
                builder.dropColumn("likes", type: .integer, null: false, from: "posts")
            }
        }

        let expectedUp = """
        ALTER TABLE IF EXISTS "posts" DROP COLUMN "likes"
        """
        let expectedDown = """
        ALTER TABLE IF EXISTS "posts" ADD COLUMN "likes" INTEGER NOT NULL
        """

        let testBuilder = SchemaBuilder()
        RemoveLikesFromPosts.change(builder: testBuilder)
        let action = try #require(testBuilder.actions.first)

        #expect(action.upSql() == expectedUp)
        #expect(action.downSql() == expectedDown)
    }
    
    @Test("AddIndex generates correct reversible SQL")
    func test_SchemaBuilder_AddIndex_IsValid() throws {
        struct AddIndexToUsers: Migration {
            static let name = "20250818183100_AddIndexToUsers"
            static func change(builder: SchemaBuilder) {
                builder.addIndex(on: "users", columns: ["email"], isUnique: true)
            }
        }
        
        let expectedUp = """
        CREATE UNIQUE INDEX "idx_users_email" ON "users" ("email")
        """
        let expectedDown = """
        DROP INDEX IF EXISTS "idx_users_email"
        """
        
        let testBuilder = SchemaBuilder()
        AddIndexToUsers.change(builder: testBuilder)
        let action = try #require(testBuilder.actions.first)

        #expect(action.upSql() == expectedUp)
        #expect(action.downSql() == expectedDown)
    }
    
    @Test("Migration and rollback works for multiple steps")
    func test_SchemaBuilder_MigrateAndRollback_IsValid() async throws {
        struct CreatePostsTable: Migration {
            static let name: String = "20250718104607_CreatePostsTable"
            static func change(builder: SchemaBuilder) {
                builder.createTable("posts") { t in
                    t.column("title", type: .text)
                }
            }
        }

        struct AddLikesToPosts: Migration {
            static let name: String = "20250718110002_AddLikesToPosts"
            static func change(builder: SchemaBuilder) {
                builder.addColumn("likes", type: .integer, null: false, table: "posts")
            }
        }

        let migrations: [ExplicitMigration.Type] = [CreatePostsTable.self, AddLikesToPosts.self]

        let dbName: String = DatabaseTestHelpers.uniqueDatabaseName()
        let db: Database = try await Database.create(name: dbName, maintenanceConfig: DatabaseTestHelpers.maintenanceConfig, eventLoopGroup: DatabaseTestHelpers.eventLoopGroup)
        defer {
            db.shutdown()
            Task {
                try await Database.drop(name: dbName, maintenanceConfig: DatabaseTestHelpers.maintenanceConfig, eventLoopGroup: DatabaseTestHelpers.eventLoopGroup)
            }
        }

        // Migrate up
        try await db.migrate(migrations)
        let rows_after_up = try await db.query("SELECT column_name FROM information_schema.columns WHERE table_name = 'posts'").collect()
        #expect(rows_after_up.count == 3) // id, title, likes

        // Rollback one step
        try await db.rollback(migrations, step: 1)
        let rows_after_rollback_1 = try await db.query("SELECT column_name FROM information_schema.columns WHERE table_name = 'posts'").collect()
        #expect(rows_after_rollback_1.count == 2) // id, title

        // Rollback another step
        try await db.rollback(migrations, step: 1)
        let tables = try await db.query("SELECT 1 FROM information_schema.tables WHERE table_name = 'posts'").collect()
        #expect(tables.isEmpty)
    }
    
    @Test("Full lifecycle with foreign keys works correctly")
    func test_SchemaBuilder_FullLifecycle_IsValid() async throws {
        struct CreateUsers: Migration {
            static let name = "20250818183200_CreateUsers"
            static func change(builder: SchemaBuilder) {
                builder.createTable("users") { t in
                    t.column("email", type: .string, null: false)
                }
            }
        }
        
        struct CreateProfiles: Migration {
            static let name = "20250818183300_CreateProfiles"
            static func change(builder: SchemaBuilder) {
                builder.createTable("profiles") { t in
                    t.references("users", null: false, onDelete: .cascade)
                }
            }
        }
        
        let migrations: [ExplicitMigration.Type] = [CreateUsers.self, CreateProfiles.self]

        let dbName: String = DatabaseTestHelpers.uniqueDatabaseName()
        let db: Database = try await Database.create(name: dbName, maintenanceConfig: DatabaseTestHelpers.maintenanceConfig, eventLoopGroup: DatabaseTestHelpers.eventLoopGroup)
        defer {
            db.shutdown()
            Task {
                try await Database.drop(name: dbName, maintenanceConfig: DatabaseTestHelpers.maintenanceConfig, eventLoopGroup: DatabaseTestHelpers.eventLoopGroup)
            }
        }
        
        try await db.migrate(migrations)
        
        // Verify foreign key exists
        let constraints = try await db.query("SELECT 1 FROM information_schema.table_constraints WHERE table_name = 'profiles' AND constraint_type = 'FOREIGN KEY'").collect()
        #expect(constraints.count == 1)
        
        // Rollback all the way
        try await db.rollback(migrations, step: 2)
        
        // Verify both tables are gone
        let tables = try await db.query("SELECT 1 FROM information_schema.tables WHERE table_name IN ('users', 'profiles')").collect()
        #expect(tables.isEmpty)
    }

        @Test("CreateTable with default value generates correct SQL")
    func test_SchemaBuilder_CreateTableWithDefault_IsValid() throws {
        struct CreateTasksTable: Migration {
            static let name = "20250819073000_CreateTasksTable"
            static func change(builder: SchemaBuilder) {
                builder.createTable("tasks") { t in
                    t.column("description", type: .text, null: false)
                    // Test default value for a boolean
                    t.column("is_complete", type: .boolean, null: false, default: "false")
                    // Test default value for a string, which requires single quotes
                    t.column("priority", type: .string, null: false, default: "'normal'")
                }
            }
        }
        
        let expectedUp = """
        CREATE TABLE IF NOT EXISTS "tasks" ("id" SERIAL PRIMARY KEY, "description" TEXT NOT NULL, "is_complete" BOOLEAN NOT NULL DEFAULT false, "priority" VARCHAR NOT NULL DEFAULT 'normal')
        """
        
        let testBuilder = SchemaBuilder()
        CreateTasksTable.change(builder: testBuilder)
        let action = try #require(testBuilder.actions.first)

        #expect(action.upSql() == expectedUp)
    }

    @Test("Default value is applied on insert")
    func test_SchemaBuilder_DefaultValueIntegration_IsValid() async throws {
        struct CreateSettingsTable: Migration {
            static let name = "20250819073100_CreateSettingsTable"
            static func change(builder: SchemaBuilder) {
                builder.createTable("settings") { t in
                    t.column("dark_mode", type: .boolean, null: false, default: "true")
                }
            }
        }

        let migrations: [ExplicitMigration.Type] = [CreateSettingsTable.self]

        let dbName: String = DatabaseTestHelpers.uniqueDatabaseName()
        let db: Database = try await Database.create(name: dbName, maintenanceConfig: DatabaseTestHelpers.maintenanceConfig, eventLoopGroup: DatabaseTestHelpers.eventLoopGroup)
        defer {
            db.shutdown()
            Task {
                try await Database.drop(name: dbName, maintenanceConfig: DatabaseTestHelpers.maintenanceConfig, eventLoopGroup: DatabaseTestHelpers.eventLoopGroup)
            }
        }

        // 1. Run the migration to create the table
        try await db.migrate(migrations)

        // 2. Insert a row without specifying the 'dark_mode' column
        _ = try await db.query("INSERT INTO \"settings\" (id) VALUES (DEFAULT)").collect()

        // 3. Fetch the row and verify the default value was applied
        let rows = try await db.query("SELECT dark_mode FROM \"settings\" WHERE id = 1").collect()
        let row = try #require(rows.first)
        let darkModeValue = try row.decode(Bool.self)
        #expect(darkModeValue == true)
        
        // 4. Rollback and ensure the table is gone
        try await db.rollback(migrations, step: 1)
        let tables = try await db.query("SELECT 1 FROM information_schema.tables WHERE table_name = 'settings'").collect()
        #expect(tables.isEmpty)
    }
}

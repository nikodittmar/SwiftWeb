//
//  SchemaBuilderTests.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 7/18/25.
//

import Testing
@testable import SwiftDB

@Suite(.serialized) struct SchemaBuilderTests {
    @Test func test_SchemaBuilder_CreateTable_IsValid() throws {
        struct CreateBooksTable: Migration {
            static let name: String = "20250718094030_CreateBooksTable"
            static func change(builder: SchemaBuilder) {
                builder.createTable("books") { t in
                    t.column("author", type: "text")
                    t.column("title", type: "text")
                }
            }
        }

        let expectedUp = """
        CREATE TABLE IF NOT EXISTS "books" ("id" SERIAL PRIMARY KEY, "author" text, "title" text)
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

    @Test func test_SchemaBuilder_DropTable_IsValid() throws {
        struct DropBooksTable: Migration {
            static let name: String = "20250718101550_DropBooksTable"
            static func change(builder: SchemaBuilder) {
                builder.dropTable("books") { t in
                    t.column("author", type: "text")
                    t.column("title", type: "text")
                }
            }
        }

        let expectedUp = """
        DROP TABLE IF EXISTS "books"
        """

        let expectedDown = """
        CREATE TABLE IF NOT EXISTS "books" ("id" SERIAL PRIMARY KEY, "author" text, "title" text)
        """

        let testBuilder = SchemaBuilder() 
        DropBooksTable.change(builder: testBuilder)
        let action = try #require(testBuilder.actions.first)

        #expect(action.upSql() == expectedUp)
        #expect(action.downSql() == expectedDown)
    }

    @Test func test_SchemaBuilder_AddColumn_IsValid() throws {
        struct AddLikesToPosts: Migration {
            static let name: String = "20250718102130_AddLikesToPosts"
            static func change(builder: SchemaBuilder) {
                builder.addColumn("likes", type: "integer", table: "posts")
            }
        }

        let expectedUp = """
        ALTER TABLE IF EXISTS "posts" ADD COLUMN "likes" integer
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

    @Test func test_SchemaBuilder_DropColumn_IsValid() throws {
        struct RemoveLikesFromPosts: Migration {
            static let name: String = "20250718102512_RemoveLikesFromPosts"
            static func change(builder: SchemaBuilder) {
                builder.dropColumn("likes", type: "integer", table: "posts")
            }
        }

        let expectedUp = """
        ALTER TABLE IF EXISTS "posts" DROP COLUMN "likes"
        """

        let expectedDown = """
        ALTER TABLE IF EXISTS "posts" ADD COLUMN "likes" integer
        """

        let testBuilder = SchemaBuilder() 
        RemoveLikesFromPosts.change(builder: testBuilder)
        let action = try #require(testBuilder.actions.first)

        #expect(action.upSql() == expectedUp)
        #expect(action.downSql() == expectedDown)
    }

    @Test func test_SchemaBuilder_Migrate_IsValid() async throws {
        struct CreatePostsTable: Migration {
            static let name: String = "20250718104607_CreatePostsTable"
            static func change(builder: SchemaBuilder) {
                builder.createTable("posts") { t in
                    t.column("author", type: "text")
                    t.column("title", type: "text")
                }
            }
        }

        struct AddLikesToPosts: Migration {
            static let name: String = "20250718110002_AddLikesToPosts"
            static func change(builder: SchemaBuilder) {
                builder.addColumn("likes", type: "integer", table: "posts")
            }
        }

        let migrations: [ExplicitMigration.Type] = [CreatePostsTable.self, AddLikesToPosts.self]

        let db = try await DatabaseTestHelpers.testDatabase()
        defer { db.shutdown() }

        try await db.migrate(migrations)

        let rows_before = try await db.query("""
            SELECT column_name FROM information_schema.columns WHERE table_name = 'posts'
        """).collect()

        #expect(rows_before.count == 4)

        try await db.rollback(migrations)

        let rows_after = try await db.query("""
            SELECT column_name FROM information_schema.columns WHERE table_name = 'posts'
        """).collect()

        #expect(rows_after.count == 3)
    }
} 
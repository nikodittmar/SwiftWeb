//
//  ModelTests.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 7/5/25.
//

import Testing
@testable import SwiftDB

@Suite(.serialized) struct ModelTests {

    struct CreateBooks: Migration {
        static let name: String = "20250718181324_CreateBooks"

        static func change(builder: SchemaBuilder) {
            builder.createTable("books") { t in
                t.column("title", type: "text")
                t.column("author", type: "text")
            }
        }
    }

    struct Book: Model {
        static let schema: String = "books"

        var id: Int?
        var title: String
        var author: String
    }

    let db: Database

    init() async throws {
        self.db = try await DatabaseTestHelpers.testDatabase()
        try await self.db.migrate([CreateBooks.self])
    }

    @Test func test_Model_Save_IsValid() async throws {
        let book = Book(title: "Swift on Server", author: "John Appleseed")
        let savedBook = try await book.save(on: db)

        #expect(savedBook.id == 1)
        #expect(savedBook.author == "John Appleseed")
        #expect(savedBook.title == "Swift on Server")
    }

    @Test func test_Model_GetAll_IsValid() async throws {
        let book1 = Book(title: "Book 1", author: "Author 1")
        let book2 = Book(title: "Book 2", author: "Author 2")
        let book3 = Book(title: "Book 3", author: "Author 3")

        _ = try await book1.save(on: db)
        _ = try await book2.save(on: db)
        _ = try await book3.save(on: db)

        let books = try await Book.all(on: db)

        let savedBook1 = try #require(books.first { $0.id == 1 })
        let savedBook2 = try #require(books.first { $0.id == 2 })
        let savedBook3 = try #require(books.first { $0.id == 3 })

        #expect(savedBook1.author == "Author 1")
        #expect(savedBook1.title == "Book 1")

        #expect(savedBook2.author == "Author 2")
        #expect(savedBook2.title == "Book 2")

        #expect(savedBook3.author == "Author 3")
        #expect(savedBook3.title == "Book 3")
    }

    @Test func test_Model_Find_IsValid() async throws {
        let book1 = Book(title: "Book 1", author: "Author 1")
        let book2 = Book(title: "Book 2", author: "Author 2")

        _ = try await book1.save(on: db)
        _ = try await book2.save(on: db)

        let book = try await Book.find(id: 2, on: db)

        #expect(book.author == "Author 2")
        #expect(book.title == "Book 2")
    }

    @Test func test_Model_Delete_IsValid() async throws {
        let book = Book(title: "Swift on Server", author: "John Appleseed")
        let savedBook = try await book.save(on: db)

        try await savedBook.destroy(on: db)

        await #expect(throws: ModelError.notFound) {
            try await Book.find(id: 1, on: db)
        }
    }

    @Test func test_Model_Update_IsValid() async throws {
        let book = Book(title: "Swift on Server", author: "John Appleseed")
        var savedBook = try await book.save(on: db)

        savedBook.title = "Swift on iOS!"

        try await savedBook.update(on: db)

        let updatedBook = try await Book.find(id: 1, on: db)

        #expect(updatedBook.title == "Swift on iOS!")
        #expect(updatedBook.author == "John Appleseed")
    }
}
//
//  ModelTests.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 7/5/25.
//

import Testing
@testable import SwiftDB

@Suite class ModelTests {

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

    let dbName: String
    let db: Database

    init() async throws {
        self.dbName = DatabaseTestHelpers.uniqueDatabaseName()
        self.db = try await Database.create(name: self.dbName, maintenanceConfig: DatabaseTestHelpers.maintenanceConfig, eventLoopGroup: DatabaseTestHelpers.eventLoopGroup)
        try await self.db.migrate([CreateBooks.self]) 
    }

    deinit {
        self.db.shutdown()
        let name = self.dbName
        Task {
            try await Database.drop(name: name, maintenanceConfig: DatabaseTestHelpers.maintenanceConfig, eventLoopGroup: DatabaseTestHelpers.eventLoopGroup)
        }
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
    /*
    @Test func test_Model_SaveComplexModel_IsValid() async throws {
        struct CreatePeopleTable: Migration {
            static let name: String = "20250718192031_CreatePeopleTable"

            static func change(builder: SchemaBuilder) {
                builder.createTable("people") { t in
                    t.column("name", type: "text")
                    t.column("age", type: "integer")
                    t.column("employment", type: "jsonb")
                    t.column("hobbies", type: "text[]")
                }
            }
        }

        struct Person: Model {
            static let schema: String = "people"

            var id: Int?
            var name: String
            var age: Int
            var employment: Employment
            var hobbies: [String]
        }

        struct Employment: Codable, Equatable {
            var company: String
            var title: String
        }

        try await self.db.migrate([CreatePeopleTable.self])

        let employment = Employment(company: "Apple", title: "Software Engineer")
        let person = Person(name: "John", age: 24, employment: employment, hobbies: ["Coding", "Golf", "Travel"])
        let savedPerson = try await person.save(on: db)

        #expect(savedPerson.id == 1)
        #expect(savedPerson.name == "John")
        #expect(savedPerson.employment == employment)
        #expect(savedPerson.hobbies[0] == "Coding")
        #expect(savedPerson.hobbies[1] == "Golf")
        #expect(savedPerson.hobbies[2] == "Travel")
    }
    */
}
//
//  ModelTests.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 7/5/25.
//

import Testing
@testable import SwiftDB
import SwiftWebCore

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
        var book = Book(title: "Swift on Server", author: "John Appleseed")
        try await book.save(on: db)

        #expect(book.id == 1)
        #expect(book.author == "John Appleseed")
        #expect(book.title == "Swift on Server")
    }

    @Test func test_Model_GetAll_IsValid() async throws {
        var book1 = Book(title: "Book 1", author: "Author 1")
        var book2 = Book(title: "Book 2", author: "Author 2")
        var book3 = Book(title: "Book 3", author: "Author 3")

        try await book1.save(on: db)
        try await book2.save(on: db)
        try await book3.save(on: db)

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
        var book1 = Book(title: "Book 1", author: "Author 1")
        var book2 = Book(title: "Book 2", author: "Author 2")

        try await book1.save(on: db)
        try await book2.save(on: db)

        let book = try await Book.find(id: 2, on: db)

        #expect(book.author == "Author 2")
        #expect(book.title == "Book 2")
    }

    @Test func test_Model_Delete_IsValid() async throws {
        var book = Book(title: "Swift on Server", author: "John Appleseed")
        try await book.save(on: db)

        try await book.destroy(on: db)

        await #expect(throws: SwiftWebError.self) {
            try await Book.find(id: 1, on: self.db)
        }
    }

    @Test func test_Model_Update_IsValid() async throws {
        var book = Book(title: "Swift on Server", author: "John Appleseed")
        try await book.save(on: db)

        book.title = "Swift on iOS!"

        try await book.update(on: db)

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

    struct CreateWidgets: Migration {
        static let name: String = "20250818172000_CreateWidgets"

        static func change(builder: SchemaBuilder) {
            builder.createTable("widgets") { t in
                t.column("name", type: "text")
                t.column("inventory", type: "integer")
            }
        }
    }

    struct Widget: Model, Equatable {
        static let schema: String = "widgets"

        var id: Int?
        var name: String
        var inventory: Int
    }

    private func seedBookData() async throws {
        var book1 = Book(title: "1984", author: "George Orwell")
        var book2 = Book(title: "Animal Farm", author: "George Orwell")
        var book3 = Book(title: "The Hobbit", author: "J.R.R. Tolkien")
        try await book1.save(on: db)
        try await book2.save(on: db)
        try await book3.save(on: db)
    }

    private func seedWidgetData() async throws {
        try await self.db.migrate([CreateWidgets.self])
        var widget1 = Widget(name: "Gizmo", inventory: 10)
        var widget2 = Widget(name: "Thingo", inventory: 50)
        var widget3 = Widget(name: "Doohickey", inventory: 100)
        var widget4 = Widget(name: "Sprocket", inventory: 50)
        try await widget1.save(on: db)
        try await widget2.save(on: db)
        try await widget3.save(on: db)
        try await widget4.save(on: db)
    }

    @Test("Model.findBy returns a single correct model or nil")
    func test_Model_FindBy_IsValid() async throws {
        try await seedBookData()

        let orwellBook = try await Book.findBy("author", is: "George Orwell", on: db)
        #expect(orwellBook != nil)

        let tolkienBook = try await Book.findBy("title", is: "The Hobbit", on: db)
        #expect(tolkienBook != nil)
        #expect(tolkienBook?.author == "J.R.R. Tolkien")
        #expect(tolkienBook?.id == 3)
        
        let nonExistentBook = try await Book.findBy("author", is: "Jane Austen", on: db)
        #expect(nonExistentBook == nil)
    }

    @Test("Model.find(where:) returns all matching models")
    func test_Model_FindWhere_IsValid() async throws {
        try await seedBookData()

        let orwellBooks = try await Book.find(where: "author", is: "George Orwell", on: db)
        #expect(orwellBooks.count == 2)
        let titles = Set(orwellBooks.map { $0.title })
        #expect(titles == Set(["1984", "Animal Farm"]))

        let tolkienBooks = try await Book.find(where: "author", is: "J.R.R. Tolkien", on: db)
        #expect(tolkienBooks.count == 1)
        #expect(tolkienBooks.first?.title == "The Hobbit")

        let nonExistentBooks = try await Book.find(where: "author", is: "Jane Austen", on: db)
        #expect(nonExistentBooks.isEmpty)
    }
    
    @Test("Model.find with operators correctly filters results")
    func test_Model_FindWithOperator_IsValid() async throws {
        try await seedWidgetData()

        let highInventoryWidgets = try await Widget.find(where: "inventory", .greaterThan, 50, on: db)
        #expect(highInventoryWidgets.count == 1)
        #expect(highInventoryWidgets.first?.name == "Doohickey")
        #expect(highInventoryWidgets.first?.inventory == 100)
        
        let lowInventoryWidgets = try await Widget.find(where: "inventory", .lessThanOrEquals, 10, on: db)
        #expect(lowInventoryWidgets.count == 1)
        #expect(lowInventoryWidgets.first?.name == "Gizmo")

        let notGizmos = try await Widget.find(where: "name", .notEquals, "Gizmo", on: db)
        #expect(notGizmos.count == 3)
        
        let midInventoryWidgets = try await Widget.find(where: "inventory", .equals, 50, on: db)
        #expect(midInventoryWidgets.count == 2)
        let names = Set(midInventoryWidgets.map { $0.name })
        #expect(names == Set(["Thingo", "Sprocket"]))

        let firstMidInventory = try await Widget.first(where: "inventory", .equals, 50, on: db)
        #expect(firstMidInventory != nil)
    }
}
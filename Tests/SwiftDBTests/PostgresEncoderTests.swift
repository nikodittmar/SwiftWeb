//
//  PostgresEncoderTests.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 7/18/25.
//

import Testing
@testable import SwiftDB
import PostgresNIO
import Foundation

@Suite struct PostgresEncoderTests {
    @Test func test_PostgresEncoder_BasicModel_IsValid() throws {
        struct Post: Model {
            static let schema: String = "posts"

            var id: Int?
            var title: String
            var author: String
        }

        let post = Post(id: nil, title: "Swift on Server", author: "John Appleseed")

        let result = try PostgresEncoder().encode(post)

        let resultTitle = try #require(result["title"] as? String)
        let resultAuthor = try #require(result["author"] as? String)

        #expect(resultTitle == "Swift on Server")
        #expect(resultAuthor == "John Appleseed")
    }

    @Test func test_PostgresEncoder_ModelWithArray_IsValid() throws {
        struct Person: Model {
            static let schema: String = "people"

            var id: Int?
            var name: String
            var hobbies: [String]
        }

        let post = Person(id: nil, name: "John Appleseed", hobbies: ["Coding", "Travelling", "Golf"])

        let result = try PostgresEncoder().encode(post)

        let resultName = try #require(result["name"] as? String)
        let resultHobbies = try #require(result["hobbies"] as? [String])

        #expect(resultName == "John Appleseed")
        #expect(resultHobbies == ["Coding", "Travelling", "Golf"])
    }

    @Test func test_PostgresEncoder_EncodeJSON_IsValid() throws {
        
        struct Book: Model {
            static let schema: String = "books"

            var id: Int?
            var title: String
            var author: Person
        }
        
        struct Person: Codable, Equatable {
            var name: String
            var age: Int
        }

        let author = Person(name: "John Appleseed", age: 28)
        let post = Book(id: nil, title: "Swift on Server Handbook", author: author)

        let result = try PostgresEncoder().encode(post)

        print(result)

        let resultTitle = try #require(result["title"] as? String)
        let resultAuthor: Person = try JSONDecoder().decode(Person.self, from: try #require(result["author"] as? Data))

        #expect(resultTitle == "Swift on Server Handbook")
        #expect(resultAuthor == author)
    }

    @Test func test_PostgresEncoder_EncodeJSONArray_IsValid() throws {
        struct Post: Model {
            static let schema: String = "people"

            var id: Int?
            var title: String
            var tags: [Tag]
        }

        struct Tag: Codable, Equatable {
            var name: String
            var color: String
        }

        let tags = [ Tag(name: "Swift", color: "Orange"), Tag(name: "Coding", color: "Blue"), Tag(name: "Tutorial", color: "Green") ]
        let post = Post(id: nil, title: "Coding in Swift", tags: tags)

        let result = try PostgresEncoder().encode(post)

        print(result)

        let resultTitle = try #require(result["title"] as? String)
        let resultTags = try #require(result["tags"] as? [String])

        let resultTag1: Tag = try JSONDecoder().decode(Tag.self, from: #require(resultTags[0].data(using: .utf8)))
        let resultTag2: Tag = try JSONDecoder().decode(Tag.self, from: #require(resultTags[1].data(using: .utf8)))
        let resultTag3: Tag = try JSONDecoder().decode(Tag.self, from: #require(resultTags[2].data(using: .utf8)))


        #expect(resultTitle == "Coding in Swift")
        #expect(resultTag1 == tags[0])
        #expect(resultTag2 == tags[1])
        #expect(resultTag3 == tags[2])
    }
}
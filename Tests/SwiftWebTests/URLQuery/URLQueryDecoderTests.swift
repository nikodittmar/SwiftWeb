//
//  URLQueryDecoderTests.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/22/25.
//
import Testing
@testable import SwiftWeb

@Suite struct URLQueryDecoderTests {
    
    @Test func test_URLQueryDecoder_WithCombinedExample_DecodesCorrectly() throws {
        struct Form: Decodable {
            let str: String
            let sentence: String
            let num: Int
            let boolTrue: Bool
            let boolFalse: Bool
            let bool1: Bool
            let bool0: Bool
            let flag: Bool
            let reservedCharacters: String
            let double: Double
        }
        
        let urlEncodedForm = "str=hello&sentence=Swift+on+server&num=25&boolTrue=True&boolFalse=false&bool1=1&bool0=0&flag&reservedCharacters=%3A%2F%3F%23%5B%5D%40%21%24%26%27%28%29%2A%2B%2C%3B%3D%25&double=6.99"
        
        let res = try URLQueryDecoder.decode(Form.self, from: urlEncodedForm)

        #expect(res.str == "hello")
        #expect(res.sentence == "Swift on server")
        #expect(res.num == 25)
        #expect(res.boolTrue == true)
        #expect(res.boolFalse == false)
        #expect(res.bool1 == true)
        #expect(res.bool0 == false)
        #expect(res.flag == true)
        #expect(res.reservedCharacters == ":/?#[]@!$&'()*+,;=%")
        #expect(res.double == 6.99)
    }
    
    @Test func test_URLQueryDecoder_WithMissingKeyForRequiredValue_ThrowsError() {
        struct Form: Decodable {
            let foo: String
            let baz: String
        }
        
        let urlEncodedForm = "foo=bar"
        
        #expect(throws: DecodingError.self) {
            try URLQueryDecoder.decode(Form.self, from: urlEncodedForm)
        }
    }
    
    @Test func test_URLQueryDecoder_WithMissingKeyForOptionalValue_DecodesAsNilForOptional() throws {
        struct Form: Decodable {
            let foo: String
            let baz: String?
        }
        
        let urlEncodedForm = "foo=bar"
        
        let res = try URLQueryDecoder.decode(Form.self, from: urlEncodedForm)
        
        #expect(res.foo == "bar")
        #expect(res.baz == nil)
    }
    
    @Test func test_URLQueryDecoder_WithInvalidPercentEncoding_ThrowsError() {
        struct Form: Decodable {
            let foo: String
        }
        
        let urlEncodedForm = "foo=bar%"
        
        #expect(throws: URLQueryParserError.self) {
            try URLQueryDecoder.decode(Form.self, from: urlEncodedForm)
        }
    }
    
    @Test func test_URLQueryDecoder_WithArray_DecodesCorrectly() throws {
        struct Form: Decodable {
            let foo: [String]
        }
        
        let urlEncodedForm = "foo%5B%5D=bar&foo%5B%5D=baz&foo%5B%5D=qux"
        
        let res = try URLQueryDecoder.decode(Form.self, from: urlEncodedForm)
        
        #expect(res.foo == ["bar", "baz", "qux"])
    }
    
    @Test func test_URLQueryDecoder_WithEmptyInput_ThrowsError() {
        struct Form: Decodable {
            let foo: String
        }
        
        let urlEncodedForm = ""
        
        #expect(throws: DecodingError.self) {
            try URLQueryDecoder.decode(Form.self, from: urlEncodedForm)
        }
    }
    
    @Test func test_URLQueryDecoder_WithLeadingAmpersand_IgnoresExtraAmpersand() throws {
        struct Form: Decodable {
            let foo: String
            let baz: String
        }
        
        let urlEncodedForm = "&foo=bar&baz=qux"
        
        let res = try URLQueryDecoder.decode(Form.self, from: urlEncodedForm)

        #expect(res.foo == "bar")
        #expect(res.baz == "qux")
    }
    
    @Test func test_URLQueryDecoder_WithTrailingAmpersand_IgnoresExtraAmpersand() throws {
        struct Form: Decodable {
            let foo: String
            let baz: String
        }
        
        let urlEncodedForm = "foo=bar&baz=qux&"

        let res = try URLQueryDecoder.decode(Form.self, from: urlEncodedForm)

        #expect(res.foo == "bar")
        #expect(res.baz == "qux")
    }
    
    @Test func test_URLQueryDecoder_WithDoubleAmpersand_IgnoresExtraAmpersand() throws {
        struct Form: Decodable {
            let foo: String
            let baz: String
        }
        
        let urlEncodedForm = "foo=bar&&baz=qux"

        let res = try URLQueryDecoder.decode(Form.self, from: urlEncodedForm)

        #expect(res.foo == "bar")
        #expect(res.baz == "qux")
    }
    
    @Test func test_URLQueryDecoder_WithMissingKey_IgnoresMissingKey() throws {
        struct Form: Decodable {
            let foo: String
        }
        
        let urlEncodedForm = "foo=bar&=baz"
        
        let res = try URLQueryDecoder.decode(Form.self, from: urlEncodedForm)
        
        #expect(res.foo == "bar")
    }
    
    @Test func test_URLQueryDecoder_WithNestedObject_DecodesCorrectly() throws {
        struct User: Decodable {
            let name: String
            let id: Int
        }
        
        struct Form: Decodable {
            let author: User
            let isActive: Bool
        }

        let urlEncodedForm = "isActive=true&author[name]=John+Appleseed&author[id]=123"
        
        let res = try URLQueryDecoder.decode(Form.self, from: urlEncodedForm)
        
        #expect(res.isActive == true)
        #expect(res.author.name == "John Appleseed")
        #expect(res.author.id == 123)
    }

    @Test func test_URLQueryDecoder_WithArrayOfObjects_DecodesCorrectly() throws {
        struct User: Decodable {
            let name: String
            let role: String
        }
        struct Form: Decodable {
            let authors: [User]
        }
        
        let urlEncodedForm = "authors[0][name]=John&authors[0][role]=admin&authors[1][name]=Jack&authors[1][role]=user"
        
        let res = try URLQueryDecoder.decode(Form.self, from: urlEncodedForm)
        
        #expect(res.authors.count == 2)
        #expect(res.authors[0].name == "John")
        #expect(res.authors[0].role == "admin")
        #expect(res.authors[1].name == "Jack")
        #expect(res.authors[1].role == "user")
    }
    
    @Test func test_URLQueryDecoder_WithDoublyNestedObject_DecodesCorrectly() throws {
        struct Point: Decodable {
            let x: Int
            let y: Int
        }
        struct Shape: Decodable {
            let type: String
            let center: Point
        }
        struct Canvas: Decodable {
            let id: String
            let shape: Shape
        }

        let urlEncodedForm = "id=canvas&shape[type]=circle&shape[center][x]=50&shape[center][y]=100"
        
        let res = try URLQueryDecoder.decode(Canvas.self, from: urlEncodedForm)

        #expect(res.id == "canvas")
        #expect(res.shape.type == "circle")
        #expect(res.shape.center.x == 50)
        #expect(res.shape.center.y == 100)
    }

    @Test func test_URLQueryDecoder_WithArrayAndNestedObject_DecodesCorrectly() throws {
        struct Comment: Decodable {
            let author: String
        }
        
        struct Post: Decodable {
            let title: String
            let tags: [String]
            let featuredComment: Comment
        }

        let urlEncodedForm = "title=Hello+World&tags[]=swift&tags[]=server&featuredComment[author]=Joe"
        
        let res = try URLQueryDecoder.decode(Post.self, from: urlEncodedForm)
        
        #expect(res.title == "Hello World")
        #expect(res.tags == ["swift", "server"])
        #expect(res.featuredComment.author == "Joe")
    }
    
    
    @Test func test_URLQueryDecoder_WithArrayOfObjectsWithMissingValue_ThrowsError() {
        struct User: Decodable {
            let name: String
            let email: String
        }
        struct UserList: Decodable {
            let users: [User]
        }
        
        let urlEncodedForm = "users[0][name]=Niko&users[0][email]=niko@example.com&users[1][name]=Jane"

        #expect(throws: DecodingError.self) {
            try URLQueryDecoder.decode(UserList.self, from: urlEncodedForm)
        }
    }
}


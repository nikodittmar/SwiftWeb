//
//  URLQueryParserTests.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/22/25.
//
import Testing
@testable import SwiftWeb

@Suite struct URLQueryParserTests {
    @Test func testValid() {
        let urlEncodedForm = "str=hello&sentence=Swift+on+server&num=25&boolTrue=True&boolFalse=false&bool1=1&bool0=0&flag&reservedCharacters=%3A%2F%3F%23%5B%5D%40%21%24%26%27%28%29%2A%2B%2C%3B%3D%25&double=6.99"
        let dict = try? URLQueryParser.parse(urlEncodedForm, mode: .encodedForm)
        #expect(dict != nil)
        #expect(dict?.count == 10)
        #expect(dict?["str"] == ["hello"])
        #expect(dict?["sentence"] == ["Swift on server"])
        #expect(dict?["num"] == ["25"])
        #expect(dict?["boolTrue"] == ["True"])
        #expect(dict?["boolFalse"] == ["false"])
        #expect(dict?["bool1"] == ["1"])
        #expect(dict?["bool0"] == ["0"])
        #expect(dict?["flag"] == [""])
        #expect(dict?["reservedCharacters"] == [":/?#[]@!$&'()*+,;=%"])
        #expect(dict?["double"] == ["6.99"])
    }
    
    @Test func testInvalidEncoding() {
        let urlEncodedForm = "foo=bar%"
        let dict = try? URLQueryParser.parse(urlEncodedForm, mode: .encodedForm)
        #expect(dict == nil)
    }
    
    @Test func testArray() {
        let urlEncodedForm = "foo%5B%5D=bar&foo%5B%5D=baz&foo%5B%5D=qux"
        let dict = try? URLQueryParser.parse(urlEncodedForm, mode: .encodedForm)
        #expect(dict != nil)
        #expect(dict?.count == 1)
        #expect(dict?["foo[]"] == ["bar", "baz", "qux"])
    }
    
    @Test func testRedeclaration() {
        let urlEncodedForm = "foo=bar&foo=baz&foo=qux"
        let dict = try? URLQueryParser.parse(urlEncodedForm, mode: .encodedForm)
        #expect(dict != nil)
        #expect(dict?.count == 1)
        #expect(dict?["foo"] == ["bar", "baz", "qux"])
    }
    
    @Test func testEmpty() {
        let urlEncodedForm = ""
        let dict = try? URLQueryParser.parse(urlEncodedForm, mode: .encodedForm)
        #expect(dict != nil)
        #expect(dict?.isEmpty == true)
    }
    
    @Test func testExtraAmpersand() {
        let trailingAmpersand = "foo=bar&baz=qux&"
        let leadingAmpersand = "&foo=bar&baz=qux"
        let doubleAmpersand = "foo=bar&&baz=qux"

        let trailingAmpersandDict = try? URLQueryParser.parse(trailingAmpersand, mode: .encodedForm)
        let leadingAmpersandDict = try? URLQueryParser.parse(leadingAmpersand, mode: .encodedForm)
        let doubleAmpersandDict = try? URLQueryParser.parse(doubleAmpersand, mode: .encodedForm)

        #expect(trailingAmpersandDict != nil)
        #expect(trailingAmpersandDict?.count == 2)
        #expect(trailingAmpersandDict?["foo"] == ["bar"])
        #expect(trailingAmpersandDict?["baz"] == ["qux"])

        #expect(leadingAmpersandDict != nil)
        #expect(leadingAmpersandDict?.count == 2)
        #expect(leadingAmpersandDict?["foo"] == ["bar"])
        #expect(leadingAmpersandDict?["baz"] == ["qux"])
        
        #expect(doubleAmpersandDict != nil)
        #expect(doubleAmpersandDict?.count == 2)
        #expect(doubleAmpersandDict?["foo"] == ["bar"])
        #expect(doubleAmpersandDict?["baz"] == ["qux"])
    }
    
    @Test func testEmptyKey() {
        let urlEncodedForm = "foo=bar&=baz"
        let dict = try? URLQueryParser.parse(urlEncodedForm, mode: .encodedForm)
        #expect(dict != nil)
        #expect(dict?.count == 1)
        #expect(dict?["foo"] == ["bar"])
    }
    
    @Test func testEmptyValue() {
        let urlEncodedForm = "foo=bar&baz="
        let dict = try? URLQueryParser.parse(urlEncodedForm, mode: .encodedForm)
        #expect(dict != nil)
        #expect(dict?.count == 2)
        #expect(dict?["foo"] == ["bar"])
        #expect(dict?["baz"] == [""])
    }
    
    @Test func testEncodedEqualsSign() {
        let urlEncodedForm = "formula=e%3Dmc%5E2"
        let dict = try? URLQueryParser.parse(urlEncodedForm, mode: .encodedForm)
        #expect(dict != nil)
        #expect(dict?.count == 1)
        #expect(dict?["formula"] == ["e=mc^2"])
    }
    
    @Test func testCaseSensitive() {
        let urlEncodedForm = "key=foo&Key=bar"
        let dict = try? URLQueryParser.parse(urlEncodedForm, mode: .encodedForm)
        #expect(dict != nil)
        #expect(dict?.count == 2)
        #expect(dict?["key"] == ["foo"])
        #expect(dict?["Key"] == ["bar"])
    }
    
    @Test func testExtraEquals() {
        let urlEncodedForm = "key=foo=bar"
        let dict = try? URLQueryParser.parse(urlEncodedForm, mode: .encodedForm)
        #expect(dict != nil)
        #expect(dict?.count == 1)
        #expect(dict?["key"] == ["foo=bar"])
    }
}

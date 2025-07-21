//
//  TokenizerTests.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/26/25.
//
import Testing
@testable import SwiftView

@Suite struct TokenizerTests {
    
    @Test func test_Tokenizer_BasicHTML_IsValid() throws {
        let input = """
        <h1>Hello Swift!</h1>
        <p>This is an application built using Swift.</p>
        """
        
        let res = try Tokenizer.tokenize(input)
                
        #expect(res.count == 1)
        #expect(res[0] == .text(input))
    }
    
    @Test func test_Tokenizer_EmptyString_IsValid() throws {
        let input = ""
        
        let res = try Tokenizer.tokenize(input)
        
        #expect(res.count == 0)
    }
    
    @Test func test_Tokenizer_SimpleExpression_IsValid() throws {
        let input = "<h1>Hello <%= name %>!</h1>"
        
        let res = try Tokenizer.tokenize(input)
                
        #expect(res.count == 3)
        #expect(res[0] == .text("<h1>Hello "))
        #expect(res[1] == .expression(" name "))
        #expect(res[2] == .text("!</h1>"))
    }
    
    @Test func test_Tokenizer_SimpleCode_IsValid() throws {
        let input = "<% for _ in users { %><div>A user</div><% } %>"
        
        let res = try Tokenizer.tokenize(input)
                
        #expect(res.count == 3)
        #expect(res[0] == .code(" for _ in users { "))
        #expect(res[1] == .text("<div>A user</div>"))
        #expect(res[2] == .code(" } "))
    }
    
    @Test func test_Tokenizer_CombinedExample_IsValid() throws {
        let input = "<% if isLoggedIn { %><div>Welcome, <%= name %>!</div><% } %>"
        
        let res = try Tokenizer.tokenize(input)
                
        #expect(res.count == 5)
        #expect(res[0] == .code(" if isLoggedIn { "))
        #expect(res[1] == .text("<div>Welcome, "))
        #expect(res[2] == .expression(" name "))
        #expect(res[3] == .text("!</div>"))
        #expect(res[4] == .code(" } "))
    }
    
    @Test func test_Tokenizer_UnclosedTag_ThrowsError() {
        let input = "<% if isLoggedIn { "
                
        #expect(throws: TokenizerError.self) {
            try Tokenizer.tokenize(input)
        }
    }
    
    @Test func test_Tokenizer_ExtraWhitespaceInTags_IsHandled() throws {
        let input = "<h1>Hello <%=  name  %>!</h1>"
        
        let res = try Tokenizer.tokenize(input)
        
        #expect(res.count == 3)
        #expect(res[1] == .expression("  name  "))
    }

    @Test func test_Tokenizer_MultiLineTags_AreHandled() throws {
        let input = """
        <%
            if isLoggedIn {
        %>
        <p>Welcome!</p>
        <%
            }
        %>
        """
        let res = try Tokenizer.tokenize(input)
        
        #expect(res.count == 3)
        #expect(res[0] == .code("\n    if isLoggedIn {\n"))
        #expect(res[1] == .text("\n<p>Welcome!</p>\n"))
        #expect(res[2] == .code("\n    }\n"))
    }
    
    @Test func test_Tokenizer_AdjacentTags_IsValid() throws {
        let input = "<% if true { %><%= name %><% } %>"
        let res = try Tokenizer.tokenize(input)
        
        #expect(res.count == 3)
        #expect(res[0] == .code(" if true { "))
        #expect(res[1] == .expression(" name "))
        #expect(res[2] == .code(" } "))
    }

    @Test func test_Tokenizer_EmptyTags_ProduceEmptyTokens() throws {
        let input = "<%%><p>Hello</p><%=%>"
        let res = try Tokenizer.tokenize(input)
        
        #expect(res.count == 3)
        #expect(res[0] == .code(""))
        #expect(res[1] == .text("<p>Hello</p>"))
        #expect(res[2] == .expression(""))
    }
    
    @Test func test_Tokenizer_MissingClosingDelimiter_ThrowsError() {
        let input = "<h1>Hello <%= name"
        
        #expect(throws: TokenizerError.self) {
            try Tokenizer.tokenize(input)
        }
    }

    @Test func test_Tokenizer_MismatchedTag_ThrowsError() {
        let input = "<%= name <% "

        #expect(throws: TokenizerError.self) {
            try Tokenizer.tokenize(input)
        }
    }
}

//
//  ScannerTests.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/29/25.
//
import Testing
@testable import SwiftView

@Suite struct ScannerTests {
    @Test func test_Scanner_IfStatement_IsValid() {
        let str = "if condition {"
        
        let res = Scanner.scan(str)
        
        #expect(res == [
            .keyword(.if),
            .identifier("condition"),
            .leftBrace
        ])
    }
    
    @Test func test_Scanner_IfStatementExtraSpace_IsValid() {
        let str = "if            condition          {"
        
        let res = Scanner.scan(str)
        
        #expect(res == [
            .keyword(.if),
            .identifier("condition"),
            .leftBrace
        ])
    }
    
    @Test func test_Scanner_ElseIfStatement_IsValid() {
        let str = "} else if condition {"
        
        let res = Scanner.scan(str)
        
        #expect(res == [
            .rightBrace,
            .keyword(.else),
            .keyword(.if),
            .identifier("condition"),
            .leftBrace
        ])
    }
    
    @Test func test_Scanner_ElseStatement_IsValid() {
        let str = "} else {"
        
        let res = Scanner.scan(str)
        
        #expect(res == [
            .rightBrace,
            .keyword(.else),
            .leftBrace
        ])
    }
    
    @Test func test_Scanner_ForLoop_IsValid() {
        let str = "for variable in collection {"
        
        let res = Scanner.scan(str)
        
        #expect(res == [
            .keyword(.for),
            .identifier("variable"),
            .keyword(.in),
            .identifier("collection"),
            .leftBrace
        ])
    }
    
    @Test func test_Scanner_ForLoopWithParenthesis_IsValid() {
        let str = "for(variable)in(collection){"
        
        let res = Scanner.scan(str)
        
        #expect(res == [
            .keyword(.for),
            .leftParen,
            .identifier("variable"),
            .rightParen,
            .keyword(.in),
            .leftParen,
            .identifier("collection"),
            .rightParen,
            .leftBrace
        ])
    }
    
    @Test func test_Scanner_OneLineIfStatement_IsValid() {
        let str = "if loggedIn { loggedInMessage } else { post.owner.name }"
        
        let res = Scanner.scan(str)
        
        #expect(res == [
            .keyword(.if),
            .identifier("loggedIn"),
            .leftBrace,
            .identifier("loggedInMessage"),
            .rightBrace,
            .keyword(.else),
            .leftBrace,
            .identifier("post.owner.name"),
            .rightBrace
        ])
    }
    
    @Test func test_Scanner_EmptyString_IsValid() {
        let str = ""
        
        let res = Scanner.scan(str)
        
        #expect(res.isEmpty)
    }
    
    @Test func test_Scanner_Expression_IsValid() {
        let str = "user.name"
        
        let res = Scanner.scan(str)
        
        #expect(res == [
            .identifier("user.name")
        ])
    }
}

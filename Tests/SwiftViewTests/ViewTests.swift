//
//  ViewTests.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/30/25.
//
import Testing
@testable import SwiftView

@Suite struct ViewTests {
    @Test func test_View_ConditionalTrue_IsValid() throws {
        let view = "<% if loggedIn { %><div>You are logged in!</div><% } %>"
        
        struct Context: Codable {
            let loggedIn: Bool
        }
        
        let res = try View.fromString(view, context: Context(loggedIn: true))
        
        #expect(res == "<div>You are logged in!</div>")
    }
}

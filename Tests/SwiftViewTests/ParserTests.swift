//
//  ParserTests.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/26/25.
//
import Testing
@testable import SwiftView

@Suite struct ParserTests {
    
    @Test func test_Parser_ForLoop_IsValid() throws {
        let tokens: [Token] = [
            .code(" for _ in loadingPosts { "),
            .text("<div>Loading...</div>"),
            .code(" } ")
        ]
        
        let res = try Parser.parse(tokens)
        
        #expect(res == [
            .loop(variable: "_", collection: "loadingPosts", body: [
                .text("<div>Loading...</div>")
            ])
        ])
    }
    
    @Test func test_Parser_UnclosedForLoop_ThrowsError() {
        let tokens: [Token] = [
            .code(" for _ in loadingPosts { "),
            .text("<div>Loading...</div>"),
        ]
                
        #expect(throws: ParserError.invalidBrackets) {
            try Parser.parse(tokens)
        }
    }
    
    @Test func test_Parser_UnopenedForLoop_ThrowsError() {
        let tokens: [Token] = [
            .code(" for _ in loadingPosts "),
            .text("<div>Loading...</div>"),
            .code(" } ")
        ]
                
        #expect(throws: ParserError.self) {
            try Parser.parse(tokens)
        }
    }
    
    @Test func test_Parser_UnopenedIfStatement_ThrowsError() {
        let tokens: [Token] = [
            .code(" if isLoggedIn "),
            .text("<div>Logged in</div>"),
            .code(" } ")
        ]
        
        #expect(throws: ParserError.self) {
            try Parser.parse(tokens)
        }
    }
    
    @Test func test_Parser_NestedLoopInConditional_IsValid() throws {
        let tokens: [Token] = [
            .code(" if isLoggedIn { "),
            .text("<div>Logged in</div>"),
            .code(" for post in user.posts { "),
            .text("<div>"),
            .expression(" post.title "),
            .text("</div>"),
            .code(" } "),
            .code(" } ")
        ]
        
        let res = try Parser.parse(tokens)
        
        #expect(res == [
            .conditional(branches: [
                Branch(condition: "isLoggedIn", body: [
                    .text("<div>Logged in</div>"),
                    .loop(variable: "post", collection: "user.posts", body: [
                        .text("<div>"),
                        .expression("post.title"),
                        .text("</div>"),
                    ])
                ])
            ], alternative: nil)
        ])
    }

    @Test func test_Parser_NestedConditionalInLoop_IsValid() throws {
        let tokens: [Token] = [
            .code(" for post in user.posts { "),
            .text("<div>"),
            .expression(" post.title "),
            .text("</div>"),
            .code(" if post.isPublished { "),
            .text("<div>Published</div>"),
            .code(" } "),
            .code(" } ")
        ]
        
        let res = try Parser.parse(tokens)
        
        #expect(res == [
            .loop(variable: "post", collection: "user.posts", body: [
                .text("<div>"),
                .expression("post.title"),
                .text("</div>"),
                .conditional(branches: [
                    Branch(condition: "post.isPublished", body: [
                        .text("<div>Published</div>"),
                    ])
                ], alternative: nil)
            ])
        ])
    }

    
    @Test func test_Parser_UnclosedIfStatement_ThrowsError() {
        let tokens: [Token] = [
            .code(" if isLoggedIn { "),
            .text("<div>Logged in</div>"),
        ]
        
        #expect(throws: ParserError.invalidBrackets) {
            try Parser.parse(tokens)
        }
    }
   
    @Test func test_Parser_ExpressionInForLoop_IsValid() throws {
        let tokens: [Token] = [
            .text("<h1>Welcome!</h1>"),
            .code(" for user in users { "),
            .text("\n<div>"),
            .expression(" user.name "),
            .text("</div>\n"),
            .code(" } ")
        ]
        
        let res = try Parser.parse(tokens)
        
        #expect(res == [
            .text("<h1>Welcome!</h1>"),
            .loop(variable: "user", collection: "users", body: [
                .text("\n<div>"),
                .expression("user.name"),
                .text("</div>\n")
            ])
        ])
    }
    
    @Test func test_Parser_ExpressionInIfStatement_IsValid() throws {
        let tokens: [Token] = [
            .text("<h1>Welcome!</h1>"),
            .code(" if isLoggedIn { "),
            .text("\n<div>"),
            .expression(" user.name "),
            .text("</div>\n"),
            .code(" } ")
        ]
        
        let res = try Parser.parse(tokens)
        
        #expect(res == [
            .text("<h1>Welcome!</h1>"),
            .conditional(branches: [
                Branch(condition: "isLoggedIn", body: [
                    .text("\n<div>"),
                    .expression("user.name"),
                    .text("</div>\n")
                ])
            ], alternative: nil)
        ])
    }
    
    @Test func test_Parser_IfElseStatement_IsValid() throws {
        let tokens: [Token] = [
            .code(" if isLoggedIn { "),
            .text("<button type=\"button\">Sign Out</button>"),
            .code(" } else { "),
            .text("<button type=\"button\">Sign In</button>"),
            .code(" } ")
        ]
        
        let res = try Parser.parse(tokens)
        
        #expect(res == [
            .conditional(branches: [
                Branch(condition: "isLoggedIn", body: [
                    .text("<button type=\"button\">Sign Out</button>")
                ])
            ], alternative: [
                .text("<button type=\"button\">Sign In</button>")
            ])
        ])
    }
    
    @Test func test_Parser_ChainedIfStatement_IsValid() throws {
        let tokens: [Token] = [
            .code(" if currentUser.isAdmin { "),
            .text("<button type=\"button\">Manage</button>"),
            .code(" } else if isOwner { "),
            .text("<button type=\"button\">Edit</button>"),
            .code(" } ")
        ]
        
        let res = try Parser.parse(tokens)
        
        #expect(res == [
            .conditional(branches: [
                Branch(condition: "currentUser.isAdmin", body: [
                    .text("<button type=\"button\">Manage</button>")
                ]),
                Branch(condition: "isOwner", body: [
                    .text("<button type=\"button\">Edit</button>")
                ])
            ], alternative: nil)
        ])
    }
    
    @Test func test_Parser_ChainedIfStatementWithElse_IsValid() throws {
        let tokens: [Token] = [
            .code(" if posts.isPlural { "),
            .text("<div>"),
            .expression(" posts.count "),
            .text(" posts</div>"),
            .code(" } else if posts.isSingular { "),
            .text("<div>"),
            .expression(" posts.count "),
            .text(" post</div>"),
            .code(" } else { "),
            .text("<div>No posts yet</div>"),
            .code(" } ")
        ]
        
        let res = try Parser.parse(tokens)
        
        #expect(res == [
            .conditional(branches: [
                Branch(condition: "posts.isPlural", body: [
                    .text("<div>"),
                    .expression("posts.count"),
                    .text(" posts</div>"),
                ]),
                Branch(condition: "posts.isSingular", body: [
                    .text("<div>"),
                    .expression("posts.count"),
                    .text(" post</div>"),
                ])
            ], alternative: [
                .text("<div>No posts yet</div>")
            ])
        ])
    }
    
    @Test func test_Parser_UnknownKeyword_ThrowsError() {
        let tokens: [Token] = [
            .code(" foobar ")
        ]
        
        #expect(throws: ParserError.syntaxError) {
            try Parser.parse(tokens)
        }
    }
    
    @Test func test_Parser_MissingIfCondition_ThrowsError() {
        let tokens: [Token] = [
            .code(" if { "),
            .text("<p>Invalid Code</p>"),
            .code(" } ")
        ]
        
        #expect(throws: ParserError.syntaxError) {
            try Parser.parse(tokens)
        }
    }
    
    @Test func test_Parser_MissingElseIfCondition_ThrowsError() {
        let tokens: [Token] = [
            .code(" if true { "),
            .text("<p>Swift on Server!</p>"),
            .code(" } else if { "),
            .text("<p>Invalid Statement</p>"),
            .code(" } ")
        ]
        
        #expect(throws: ParserError.syntaxError) {
            try Parser.parse(tokens)
        }
    }
    
    @Test func test_Parser_MissingLoopVariable_ThrowsError() {
        let tokens: [Token] = [
            .code(" for in greetings { "),
            .text("<p>Hello!</p>"),
            .code(" }"),
        ]
        
        #expect(throws: ParserError.syntaxError) {
            try Parser.parse(tokens)
        }
    }
    
    @Test func test_Parser_MissingLoopCollection_ThrowsError() {
        let tokens: [Token] = [
            .code(" for greeting in { "),
            .text("<p>Hello!</p>"),
            .code(" }"),
        ]
        
        #expect(throws: ParserError.syntaxError) {
            try Parser.parse(tokens)
        }
    }
    
    @Test func test_Parser_UnopenedElseBracket_ThrowsError() {
        let tokens: [Token] = [
            .code(" if isLoggedIn { "),
            .text("<button type=\"button\">Sign Out</button>"),
            .code(" } else "),
            .text("<button type=\"button\">Sign In</button>"),
            .code(" } ")
        ]
                
        #expect(throws: ParserError.self) {
            try Parser.parse(tokens)
        }
    }
    
    @Test func test_Parser_UnclosedElseBracket_ThrowsError() {
        let tokens: [Token] = [
            .code(" if isLoggedIn { "),
            .text("<button type=\"button\">Sign Out</button>"),
            .code(" } else { "),
            .text("<button type=\"button\">Sign In</button>"),
            .code(" ")
        ]
                
        #expect(throws: ParserError.invalidBrackets) {
            try Parser.parse(tokens)
        }
    }
    
    @Test func test_Parser_UnclosedChainedIfBracket_ThrowsError() {
        let tokens: [Token] = [
            .code(" if currentUser.isAdmin { "),
            .text("<button type=\"button\">Manage</button>"),
            .code(" } else if currentUser.isAuthor { "),
            .text("<button type=\"button\">Edit</button>"),
            .code(" ")
        ]
        
        #expect(throws: ParserError.invalidBrackets) {
            try Parser.parse(tokens)
        }
    }
    
    @Test func test_Parser_UnopenedChainedIfBracket_ThrowsError() {
        let tokens: [Token] = [
            .code(" if currentUser.isAdmin { "),
            .text("<button type=\"button\">Manage</button>"),
            .code(" } else if currentUser.isAuthor "),
            .text("<button type=\"button\">Edit</button>"),
            .code(" } ")
        ]
        
        #expect(throws: ParserError.invalidBrackets) {
            try Parser.parse(tokens)
        }
    }
    
    @Test func test_Parser_ElseAfterLoop_ThrowsError() {
        let tokens: [Token] = [
            .code(" for post in posts { "),
            .text("<h2>A post!</h2>"),
            .code(" } else { "),
            .text("<p>No posts found</p>"),
            .code(" } ")
        ]
        
        #expect(throws: ParserError.syntaxError) {
            try Parser.parse(tokens)
        }
    }

    @Test func test_Parser_ConsecutiveIfAndLoop_ThrowsError() {
        let tokens: [Token] = [
            .code(" if loggedIn { "),
            .text("<h2>A post!</h2>"),
            .code(" } for post in posts { "),
            .text("<h2>A post!</h2>"),
            .code(" } ")
        ]
        
        #expect(throws: ParserError.syntaxError) {
            try Parser.parse(tokens)
        }
    }
    
    @Test func test_Parser_OnlyText_IsValid() throws {
        let tokens: [Token] = [
            .text("<h1>Hello World</h1>")
        ]
        
        let res = try Parser.parse(tokens)
        
        #expect(res == [
            .text("<h1>Hello World</h1>")
        ])
    }

    @Test func test_Parser_OnlyExpression_IsValid() throws {
        let tokens: [Token] = [
            .expression(" user.name ")
        ]
        
        let res = try Parser.parse(tokens)
        
        #expect(res == [
            .expression("user.name")
        ])
    }
    
    @Test func test_Parser_EmptyIfBlock_IsValid() throws {
        let tokens: [Token] = [
            .code(" if true { "), .code(" } ")
        ]
        
        let res = try Parser.parse(tokens)
        
        #expect(res == [
            .conditional(branches: [
                Branch(condition: "true", body: [])
            ], alternative: nil)
        ])
    }

    @Test func test_Parser_EmptyForLoopBlock_IsValid() throws {
        let tokens: [Token] = [
            .code(" for item in items { "), .code(" } ")
        ]
        
        let res = try Parser.parse(tokens)
        
        #expect(res == [
            .loop(variable: "item", collection: "items", body: [])
        ])
    }
    
    @Test func test_Parser_MismatchedNestedBraces_ThrowsError() {
        let tokens: [Token] = [
            .code(" if true { "),
            .code(" for item in items { "),
            .text("test"),
            .code(" } ")
        ]
        
        #expect(throws: ParserError.invalidBrackets) {
            try Parser.parse(tokens)
        }
    }
    
    @Test func test_Parser_Empty_IsValid() throws {
        let tokens: [Token] = []
        
        let res = try Parser.parse(tokens)
        
        #expect(res == [])
    }
    
    @Test func test_Parser_ExtraWhitespaceInCondition_IsValid() throws {
        let tokens: [Token] = [
            .code(" if   user.isLoggedIn   { }")
        ]
        
        let res = try Parser.parse(tokens)

        #expect(res == [
            .conditional(branches: [
                Branch(condition: "user.isLoggedIn", body: [])
            ], alternative: nil)
        ])
    }
    
    @Test func test_Parser_MultilineIfStatement_IsValid() throws {
        let tokens: [Token] = [
            .code("if"),
            .code("condition"),
            .code("{"),
            .code("}")
        ]
        
        let res = try Parser.parse(tokens)

        #expect(res == [
            .conditional(branches: [
                Branch(condition: "condition", body: [])
            ], alternative: nil)
        ])
    }
    
    @Test func test_Parser_MultilineLoop_IsValid() throws {
        let tokens: [Token] = [
            .code("for"),
            .code("item"),
            .code("in"),
            .code("items"),
            .code("{"),
            .code("}")
        ]
        
        let res = try Parser.parse(tokens)

        #expect(res == [
            .loop(variable: "item", collection: "items", body: [])
        ])
    }
    
    @Test func test_Parser_MultilineElse_IsValid() throws {
        let tokens: [Token] = [
            .code("if condition {"),
            .text("<h1>Hello!!</h1>"),
            .code("}"),
            .code("else"),
            .code("{"),
            .text("<h1>Goodbye!!</h1>"),
            .code("}")
        ]
        
        let res = try Parser.parse(tokens)

        #expect(res == [
            .conditional(branches: [
                Branch(condition: "condition", body: [
                    .text("<h1>Hello!!</h1>")
                ])
            ], alternative: [
                .text("<h1>Goodbye!!</h1>")
            ])
        ])
    }
    
    @Test func test_Parser_MultilineElseIf_IsValid() throws {
        let tokens: [Token] = [
            .code("if condition {"),
            .text("<h1>Hello!!</h1>"),
            .code("}"),
            .code("else"),
            .code("if"),
            .code("anotherCondition"),
            .code("{"),
            .text("<h1>Goodbye!!</h1>"),
            .code("}")
        ]
        
        let res = try Parser.parse(tokens)

        #expect(res == [
            .conditional(branches: [
                Branch(condition: "condition", body: [
                    .text("<h1>Hello!!</h1>")
                ]),
                Branch(condition: "anotherCondition", body: [
                    .text("<h1>Goodbye!!</h1>")
                ])
            ], alternative: nil)
        ])
    }
}


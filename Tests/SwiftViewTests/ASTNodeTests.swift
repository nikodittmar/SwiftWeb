//
//  ASTNodeTests.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/30/25.
//
import Testing
@testable import SwiftView

@Suite struct ASTNodeTests {
    @Test func test_ASTNode_AddTextDepthZero_IsValid() throws {
        var syntaxTree: [ASTNode] = [
            .text("<h1>Swift on Server!</h1>"),
            .conditional(branches: [
                Branch(condition: "isLoggedIn", body: [
                    .text("<div>Welcome, logged in user!</div>")
                ])
            ], alternative: nil)
        ]
        
        try syntaxTree.addNode(.text("<div>This is built using swift!</div>"), depth: 0)
        
        #expect(syntaxTree == [
            .text("<h1>Swift on Server!</h1>"),
            .conditional(branches: [
                Branch(condition: "isLoggedIn", body: [
                    .text("<div>Welcome, logged in user!</div>")
                ])
            ], alternative: nil),
            .text("<div>This is built using swift!</div>")
        ])
    }
    
    @Test func test_ASTNode_AddTextToEmpty_IsValid() throws {
        var syntaxTree: [ASTNode] = []
        
        try syntaxTree.addNode(.text("<h1>Swift on Server!</h1>"), depth: 0)
        
        #expect(syntaxTree == [
            .text("<h1>Swift on Server!</h1>")
        ])
    }
    
    @Test func test_ASTNode_AddTextDepthOneToLoop_IsValid() throws {
        var syntaxTree: [ASTNode] = [
            .text("<h1>Swift on Server!</h1>"),
            .loop(variable: "user", collection: "users", body: [
                .text("<div>Hello, "),
                .expression("user.name")
            ])
        ]
        
        try syntaxTree.addNode(.text("</div>"), depth: 1)
        
        #expect(syntaxTree == [
            .text("<h1>Swift on Server!</h1>"),
            .loop(variable: "user", collection: "users", body: [
                .text("<div>Hello, "),
                .expression("user.name"),
                .text("</div>")
            ])
        ])
    }
    
    @Test func test_ASTNode_AddTextDepthOneToConditional_IsValid() throws {
        var syntaxTree: [ASTNode] = [
            .text("<h1>Swift on Server!</h1>"),
            .conditional(branches: [
                Branch(condition: "isLoggedIn", body: [
                    .text("<div>Welcome, logged in user!</div>")
                ])
            ], alternative: nil)
        ]
        
        try syntaxTree.addNode(.text("<div>This is built using swift!</div>"), depth: 1)
        
        #expect(syntaxTree == [
            .text("<h1>Swift on Server!</h1>"),
            .conditional(branches: [
                Branch(condition: "isLoggedIn", body: [
                    .text("<div>Welcome, logged in user!</div>"),
                    .text("<div>This is built using swift!</div>")
                ])
            ], alternative: nil),
        ])
    }
    
    @Test func test_ASTNode_AddTextDepthOneToSecondBranch_IsValid() throws {
        var syntaxTree: [ASTNode] = [
            .text("<h1>Swift on Server!</h1>"),
            .conditional(branches: [
                Branch(condition: "isLoggedIn", body: [
                    .text("<div>Welcome, logged in user!</div>")
                ]),
                Branch(condition: "isAdmin", body: [
                    .text("<div>Welcome, admin user!</div>")
                ])
            ], alternative: nil)
        ]
        
        try syntaxTree.addNode(.text("<div>This is only visible if you are an admin!</div>"), depth: 1)
        
        #expect(syntaxTree == [
            .text("<h1>Swift on Server!</h1>"),
            .conditional(branches: [
                Branch(condition: "isLoggedIn", body: [
                    .text("<div>Welcome, logged in user!</div>")
                ]),
                Branch(condition: "isAdmin", body: [
                    .text("<div>Welcome, admin user!</div>"),
                    .text("<div>This is only visible if you are an admin!</div>")
                ])
            ], alternative: nil)
        ])
    }
    
    @Test func test_ASTNode_AddTextDepthOneToAlternative_IsValid() throws {
        var syntaxTree: [ASTNode] = [
            .text("<h1>Swift on Server!</h1>"),
            .conditional(branches: [
                Branch(condition: "isLoggedIn", body: [
                    .text("<div>Welcome, logged in user!</div>")
                ])
            ], alternative: [
                .text("<div>You are not logged in!</div>")
            ])
        ]
        
        try syntaxTree.addNode(.text("<button>Login</button>"), depth: 1)
        
        #expect(syntaxTree == [
            .text("<h1>Swift on Server!</h1>"),
            .conditional(branches: [
                Branch(condition: "isLoggedIn", body: [
                    .text("<div>Welcome, logged in user!</div>")
                ])
            ], alternative: [
                .text("<div>You are not logged in!</div>"),
                .text("<button>Login</button>")
            ])
        ])
    }
    
    @Test func test_ASTNode_AddTextDepthTwo_IsValid() throws {
        var syntaxTree: [ASTNode] = [
            .loop(variable: "user", collection: "users", body: [
                .conditional(branches: [
                    Branch(condition: "user.isAdmin", body: [
                        
                    ])
                ], alternative: nil)
            ])
        ]
        
        try syntaxTree.addNode(.text("<div>Hello admin!</div>"), depth: 2)
        
        #expect(syntaxTree == [
            .loop(variable: "user", collection: "users", body: [
                .conditional(branches: [
                    Branch(condition: "user.isAdmin", body: [
                        .text("<div>Hello admin!</div>")
                    ])
                ], alternative: nil)
            ])
        ])
    }
    
    @Test func test_ASTNode_AddTextInvalidDepth_ThrowsError() {
        var syntaxTree: [ASTNode] = [
            .loop(variable: "user", collection: "users", body: [
                .conditional(branches: [
                    Branch(condition: "user.isAdmin", body: [
                        
                    ])
                ], alternative: nil)
            ])
        ]
        
        #expect(throws: ParserError.self) {
            try syntaxTree.addNode(.text("<div>Hello admin!</div>"), depth: 3)
        }
    }
    
    @Test func test_ASTNode_AddTextNegativeDepth_ThrowsError() {
        var syntaxTree: [ASTNode] = [
            .loop(variable: "user", collection: "users", body: [
                .conditional(branches: [
                    Branch(condition: "user.isAdmin", body: [
                        
                    ])
                ], alternative: nil)
            ])
        ]
        
        #expect(throws: ParserError.self) {
            try syntaxTree.addNode(.text("<div>Hello admin!</div>"), depth: -1)
        }
    }
    
    @Test func test_ASTNode_AddBranch_IsValid() throws {
        var syntaxTree: [ASTNode] = [
            .conditional(branches: [
                Branch(condition: "isAdmin", body: [
                    .text("<div>Hello admin!</div>")
                ])
            ], alternative: nil)
        ]
        
        try syntaxTree.addBranch(Branch(condition: "isLoggedIn", body: []), depth: 0)
        
        #expect(syntaxTree == [
            .conditional(branches: [
                Branch(condition: "isAdmin", body: [
                    .text("<div>Hello admin!</div>")
                ]),
                Branch(condition: "isLoggedIn", body: [])
            ], alternative: nil)
        ])
    }
    
    @Test func test_ASTNode_AddBranchToConditionalWithAlternative_ThrowsError() {
        var syntaxTree: [ASTNode] = [
            .conditional(branches: [
                Branch(condition: "isAdmin", body: [
                    .text("<div>Hello admin!</div>")
                ])
            ], alternative: [
                .text("<div>Hello world!</div>")
            ])
        ]
        
        #expect(throws: ParserError.self) {
            try syntaxTree.addBranch(Branch(condition: "isLoggedIn", body: []), depth: 0)
        }
    }
    
    @Test func test_ASTNode_AddBranchDepthOne_IsValid() throws {
        var syntaxTree: [ASTNode] = [
            .conditional(branches: [
                Branch(condition: "isLoggedIn", body: [
                    .conditional(branches: [
                        Branch(condition: "isAdmin", body: [
                            .text("<button>Manage</button>")
                        ])
                    ], alternative: nil)
                ])
            ], alternative: nil)
        ]
        
        try syntaxTree.addBranch(Branch(condition: "isOwner", body: []), depth: 1)
        
        #expect(syntaxTree == [
            .conditional(branches: [
                Branch(condition: "isLoggedIn", body: [
                    .conditional(branches: [
                        Branch(condition: "isAdmin", body: [
                            .text("<button>Manage</button>")
                        ]),
                        Branch(condition: "isOwner", body: [])
                    ], alternative: nil)
                ])
            ], alternative: nil)
        ])
    }
    
    @Test func test_ASTNode_AddBranchInvaidDepth_ThrowsError() {
        var syntaxTree: [ASTNode] = [
            .conditional(branches: [
                Branch(condition: "isLoggedIn", body: [
                    .conditional(branches: [
                        Branch(condition: "isAdmin", body: [
                            .text("<button>Manage</button>")
                        ])
                    ], alternative: nil)
                ])
            ], alternative: nil)
        ]
        
        #expect(throws: ParserError.self) {
            try syntaxTree.addBranch(Branch(condition: "isOwner", body: []), depth: 2)
        }
    }
    
    @Test func test_ASTNode_AddBranchNegativeDepth_ThrowsError() {
        var syntaxTree: [ASTNode] = [
            .conditional(branches: [
                Branch(condition: "isLoggedIn", body: [
                    .conditional(branches: [
                        Branch(condition: "isAdmin", body: [
                            .text("<button>Manage</button>")
                        ])
                    ], alternative: nil)
                ])
            ], alternative: nil)
        ]
        
        #expect(throws: ParserError.self) {
            try syntaxTree.addBranch(Branch(condition: "isOwner", body: []), depth: -1)
        }
    }
    
    @Test func test_ASTNode_AddAlternative_IsValid() throws {
        var syntaxTree: [ASTNode] = [
            .conditional(branches: [
                Branch(condition: "isAdmin", body: [
                    .text("<div>Hello admin!</div>")
                ])
            ], alternative: nil)
        ]
        
        try syntaxTree.addAlternative(depth: 0)
        
        #expect(syntaxTree == [
            .conditional(branches: [
                Branch(condition: "isAdmin", body: [
                    .text("<div>Hello admin!</div>")
                ])
            ], alternative: [])
        ])
    }
    
    @Test func test_ASTNode_AddAlternativeEmptyBranches_ThrowsError() {
        var syntaxTree: [ASTNode] = [
            .conditional(branches: [], alternative: nil)
        ]
        
        #expect(throws: ParserError.self) {
            try syntaxTree.addAlternative(depth: 0)
        }
    }
    
    @Test func test_ASTNode_AddAlternativeDepthOne_IsValid() throws {
        var syntaxTree: [ASTNode] = [
            .conditional(branches: [
                Branch(condition: "isLoggedIn", body: [
                    .conditional(branches: [
                        Branch(condition: "isAdmin", body: [
                            .text("<button>Manage</button>")
                        ])
                    ], alternative: nil)
                ])
            ], alternative: nil)
        ]
        
        try syntaxTree.addAlternative(depth: 1)
        
        #expect(syntaxTree == [
            .conditional(branches: [
                Branch(condition: "isLoggedIn", body: [
                    .conditional(branches: [
                        Branch(condition: "isAdmin", body: [
                            .text("<button>Manage</button>")
                        ]),
                    ], alternative: [])
                ])
            ], alternative: nil)
        ])
    }
    
    @Test func test_ASTNode_AddNodeToEmptyScopeInvalidDepth_ThrowsError() {
        var syntaxTree: [ASTNode] = []

        #expect(throws: ParserError.self) {
            try syntaxTree.addNode(.text("<h1>Some text</h1>"), depth: 1)
        }
    }

    @Test func test_ASTNode_AddBranchToEmptyScope_ThrowsError() {
        var syntaxTree: [ASTNode] = []

        #expect(throws: ParserError.self) {
            try syntaxTree.addBranch(Branch(condition: "isLoggedIn", body: []), depth: 0)
        }
    }

    @Test func test_ASTNode_AddAlternativeToEmptyScope_ThrowsError() {
        var syntaxTree: [ASTNode] = []

        #expect(throws: ParserError.self) {
            try syntaxTree.addAlternative(depth: 0)
        }
    }

    @Test func test_ASTNode_AddNodeToTextNode_ThrowsError() {
        var syntaxTree: [ASTNode] = [ .text("<h1>Some text</h1>") ]

        #expect(throws: ParserError.self) {
            try syntaxTree.addNode(.text("<h1>More text</h1>"), depth: 1)
        }
    }

    @Test func test_ASTNode_AddBranchToTextNode_ThrowsError() {
        var syntaxTree: [ASTNode] = [ .text("<h1>Some text</h1>") ]

        #expect(throws: ParserError.self) {
            try syntaxTree.addBranch(Branch(condition: "isLoggedIn", body: []), depth: 1)
        }
    }

    @Test func test_ASTNode_AddAlternativeToTextNode_ThrowsError() {
        var syntaxTree: [ASTNode] = [ .text("<h1>Some text</h1>") ]

        #expect(throws: ParserError.self) {
            try syntaxTree.addAlternative(depth: 1)
        }
    }

    @Test func test_ASTNode_AddAlternativeToCorrectNestedSibling() throws {
        var syntaxTree: [ASTNode] = [
            .conditional(branches: [Branch(condition: "isGuest", body: [])], alternative: nil),
            .conditional(branches: [Branch(condition: "isMember", body: [])], alternative: nil)
        ]
        
        try syntaxTree.addAlternative(depth: 0)
        
        #expect(syntaxTree == [
            .conditional(branches: [Branch(condition: "isGuest", body: [])], alternative: nil),
            .conditional(branches: [Branch(condition: "isMember", body: [])], alternative: [])
        ])
    }
}

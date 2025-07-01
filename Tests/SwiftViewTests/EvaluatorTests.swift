//
//  EvaluatorTests.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/30/25.
//
import Testing
@testable import SwiftView

@Suite struct EvaluatorTests {
    
    @Test func test_Evaluator_BasicText_IsValid() throws {
        let syntaxTree: [ASTNode] = [
            .text("<h1>Hello Swift!</h1>"),
        ]
        
        struct Context: Codable {}
            
        let res = try Evaluator.evaluate(syntaxTree: syntaxTree, context: Context())
        
        #expect(res == "<h1>Hello Swift!</h1>")
    }
    
    @Test func test_Evaluator_CombinesText_IsValid() throws {
        let syntaxTree: [ASTNode] = [
            .text("<h1>Hello Swift!</h1>"),
            .text("<div>This was built using Swift!!</div>")
        ]
        
        struct Context: Codable {}
            
        let res = try Evaluator.evaluate(syntaxTree: syntaxTree, context: Context())
        
        #expect(res == "<h1>Hello Swift!</h1><div>This was built using Swift!!</div>")
    }
    
    @Test func test_Evaluator_ConditionalTrue_IsValid() throws {
        let syntaxTree: [ASTNode] = [
            .conditional(
                branches: [
                    Branch(
                        condition: "isLoggedIn",
                        body: [
                            .text("<h1>Hello!</h1>")
                        ]
                    )
                ],
                alternative: nil
            )
        ]

        struct Context: Codable {
            let isLoggedIn: Bool
        }
            
        let res = try Evaluator.evaluate(syntaxTree: syntaxTree, context: Context(isLoggedIn: true))
        
        #expect(res == "<h1>Hello!</h1>")
    }
    
    @Test func test_Evaluator_ConditionalFalse_IsValid() throws {
        let syntaxTree: [ASTNode] = [
            .conditional(
                branches: [
                    Branch(
                        condition: "isLoggedIn",
                        body: [
                            .text("<h1>Hello!</h1>")
                        ]
                    )
                ],
                alternative: nil
            )
        ]
        
        struct Context: Codable {
            let isLoggedIn: Bool
        }
            
        let res = try Evaluator.evaluate(syntaxTree: syntaxTree, context: Context(isLoggedIn: false))
        
        #expect(res == "")
    }
    
    @Test func test_Evaluator_ElseTrue_IsValid() throws {
        let syntaxTree: [ASTNode] = [
            .conditional(
                branches: [
                    Branch(
                        condition: "greet",
                        body: [
                            .text("<h1>Hello!</h1>")
                        ]
                    )
                ],
                alternative: [
                    .text("<h1>Goodbye!</h1>")
                ]
            )
        ]
        
        struct Context: Codable {
            let greet: Bool
        }
            
        let res = try Evaluator.evaluate(syntaxTree: syntaxTree, context: Context(greet: true))
        
        #expect(res == "<h1>Hello!</h1>")
    }
    
    @Test func test_Evaluator_ElseFalse_IsValid() throws {
        let syntaxTree: [ASTNode] = [
            .conditional(
                branches: [
                    Branch(
                        condition: "greet",
                        body: [
                            .text("<h1>Hello!</h1>")
                        ]
                    )
                ],
                alternative: [
                    .text("<h1>Goodbye!</h1>")
                ]
            )
        ]
        
        struct Context: Codable {
            let greet: Bool
        }
            
        let res = try Evaluator.evaluate(syntaxTree: syntaxTree, context: Context(greet: false))
        
        #expect(res == "<h1>Goodbye!</h1>")
    }
    
    @Test func test_Evaluator_ElseIfFirstConditionTrue_IsValid() throws {
        let syntaxTree: [ASTNode] = [
            .conditional(
                branches: [
                    Branch(
                        condition: "sayHello",
                        body: [
                            .text("<h1>Hello!</h1>")
                        ]
                    ),
                    Branch(
                        condition: "sayGoodbye",
                        body: [
                            .text("<h1>Goodbye!</h1>")
                        ]
                    )
                ],
                alternative: nil
            )
        ]
        
        struct Context: Codable {
            let sayHello: Bool
            let sayGoodbye: Bool
        }
            
        let res = try Evaluator.evaluate(syntaxTree: syntaxTree, context: Context(sayHello: true, sayGoodbye: false))
        
        #expect(res == "<h1>Hello!</h1>")
    }
    
    @Test func test_Evaluator_ElseIfSecondConditionTrue_IsValid() throws {
        let syntaxTree: [ASTNode] = [
            .conditional(
                branches: [
                    Branch(
                        condition: "sayHello",
                        body: [
                            .text("<h1>Hello!</h1>")
                        ]
                    ),
                    Branch(
                        condition: "sayGoodbye",
                        body: [
                            .text("<h1>Goodbye!</h1>")
                        ]
                    )
                ],
                alternative: nil
            )
        ]
        
        struct Context: Codable {
            let sayHello: Bool
            let sayGoodbye: Bool
        }
            
        let res = try Evaluator.evaluate(syntaxTree: syntaxTree, context: Context(sayHello: false, sayGoodbye: true))
        
        #expect(res == "<h1>Goodbye!</h1>")
    }
    
    @Test func test_Evaluator_ElseIfBothConditionsTrue_IsValid() throws {
        let syntaxTree: [ASTNode] = [
            .conditional(
                branches: [
                    Branch(
                        condition: "sayHello",
                        body: [
                            .text("<h1>Hello!</h1>")
                        ]
                    ),
                    Branch(
                        condition: "sayGoodbye",
                        body: [
                            .text("<h1>Goodbye!</h1>")
                        ]
                    )
                ],
                alternative: nil
            )
        ]
        
        struct Context: Codable {
            let sayHello: Bool
            let sayGoodbye: Bool
        }
            
        let res = try Evaluator.evaluate(syntaxTree: syntaxTree, context: Context(sayHello: true, sayGoodbye: true))
        
        #expect(res == "<h1>Hello!</h1>")
    }
    
    @Test func test_Evaluator_ElseIfBothConditionsFalse_IsValid() throws {
        let syntaxTree: [ASTNode] = [
            .conditional(
                branches: [
                    Branch(
                        condition: "sayHello",
                        body: [
                            .text("<h1>Hello!</h1>")
                        ]
                    ),
                    Branch(
                        condition: "sayGoodbye",
                        body: [
                            .text("<h1>Goodbye!</h1>")
                        ]
                    )
                ],
                alternative: nil
            )
        ]
        
        struct Context: Codable {
            let sayHello: Bool
            let sayGoodbye: Bool
        }
            
        let res = try Evaluator.evaluate(syntaxTree: syntaxTree, context: Context(sayHello: false, sayGoodbye: false))
        
        #expect(res == "")
    }
    
    @Test func test_Evaluator_ConditionalMissingValue_ThrowsError() {
        let syntaxTree: [ASTNode] = [
            .conditional(
                branches: [
                    Branch(
                        condition: "isLoggedIn",
                        body: [
                            .text("<h1>Hello!</h1>")
                        ]
                    )
                ],
                alternative: nil
            )
        ]
        
        struct Context: Codable {}
                    
        #expect(throws: EvaluatorError.self) {
            try Evaluator.evaluate(syntaxTree: syntaxTree, context: Context())
        }
    }
    
    @Test func test_Evaluator_ConditionalIncorrectValueType_ThrowsError() {
        let syntaxTree: [ASTNode] = [
            .conditional(
                branches: [
                    Branch(
                        condition: "isLoggedIn",
                        body: [
                            .text("<h1>Hello!</h1>")
                        ]
                    )
                ],
                alternative: nil
            )
        ]
        
        struct Context: Codable {
            let isLoggedIn: String
        }
        
        #expect(throws: EvaluatorError.self) {
            try Evaluator.evaluate(syntaxTree: syntaxTree, context: Context(isLoggedIn: "NOT A BOOLEAN"))
        }
    }
    
    @Test func test_Evaluator_Expression_IsValid() throws {
        let syntaxTree: [ASTNode] = [
            .expression("name"),
        ]
        
        struct Context: Codable {
            let name: String
        }
            
        let res = try Evaluator.evaluate(syntaxTree: syntaxTree, context: Context(name: "Niko"))
                
        #expect(res == "Niko")
    }
    
    @Test func test_Evaluator_ExpressionMissingValue_ThrowsError() {
        let syntaxTree: [ASTNode] = [
            .expression("name"),
        ]
        
        struct Context: Codable {}
                    
        #expect(throws: EvaluatorError.self) {
            try Evaluator.evaluate(syntaxTree: syntaxTree, context: Context())
        }
    }
    
    @Test func test_Evaluator_Loop_IsValid() throws {
        let syntaxTree: [ASTNode] = [
            .text("<ul>"),
            .loop(variable: "name", collection: "names", body: [
                .text("<li>"),
                .expression("name"),
                .text("</li>"),
            ]),
            .text("</ul>"),
        ]
        
        struct Context: Codable {
            let names: [String]
        }
        
        let res = try Evaluator.evaluate(syntaxTree: syntaxTree, context: Context(names: [ "Niko", "John", "Adam", "Michael" ]))
        
        #expect(res == "<ul><li>Niko</li><li>John</li><li>Adam</li><li>Michael</li></ul>")
    }
    
    @Test func test_Evaluator_LoopEmptyCollection_IsValid() throws {
        let syntaxTree: [ASTNode] = [
            .text("<ul>"),
            .loop(variable: "name", collection: "names", body: [
                .text("<li>"),
                .expression("name"),
                .text("</li>"),
            ]),
            .text("</ul>"),
        ]
        
        struct Context: Codable {
            let names: [String]
        }
        
        let res = try Evaluator.evaluate(syntaxTree: syntaxTree, context: Context(names: []))
        
        #expect(res == "<ul></ul>")
    }
    
    @Test func test_Evaluator_MissingCollectionVariable_ThrowsError() {
        let syntaxTree: [ASTNode] = [
            .text("<ul>"),
            .loop(variable: "name", collection: "names", body: [
                .text("<li>"),
                .expression("name"),
                .text("</li>"),
            ]),
            .text("</ul>"),
        ]
        
        struct Context: Codable {}
                    
        #expect(throws: EvaluatorError.self) {
            try Evaluator.evaluate(syntaxTree: syntaxTree, context: Context())
        }
    }
    
    @Test func test_Evaluator_Empty_IsValid() throws {
        let syntaxTree: [ASTNode] = []
        
        struct Context: Codable {}
        
        let res = try Evaluator.evaluate(syntaxTree: syntaxTree, context: Context())
        
        #expect(res == "")
    }
    
    @Test func test_Evaluator_ExpressionDotNotation_IsValid() throws {
        let syntaxTree: [ASTNode] = [
            .text("<div>Your name is "),
            .expression("user.name"),
            .text(" and you are "),
            .expression("user.age"),
            .text(" years old!</div>")
        ]
        
        struct User: Codable {
            let name: String
            let age: Int
        }
        
        struct Context: Codable {
            let user: User
        }
        
        let res = try Evaluator.evaluate(syntaxTree: syntaxTree, context: Context(user: User(name: "Niko", age: 20)))
        
        #expect(res == "<div>Your name is Niko and you are 20 years old!</div>")
    }
    
    @Test func test_Evaluator_LoopWithDotNotation_IsValid() throws {
        let syntaxTree: [ASTNode] = [
            .text("<div>Posts: "),
            .loop(variable: "post", collection: "posts", body: [
                .expression("post.title"),
                .text(", ")
            ]),
            .text("</div>")
        ]
        
        struct Post: Codable {
            let title: String
        }
        
        struct Context: Codable {
            let posts: [Post]
        }
        
        let res = try Evaluator.evaluate(syntaxTree: syntaxTree, context: Context(posts: [ Post(title: "Post 1"), Post(title: "Post 2"), Post(title: "Post 3") ]))
        
        #expect(res == "<div>Posts: Post 1, Post 2, Post 3, </div>")
    }
}

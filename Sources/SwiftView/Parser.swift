//
//  Parser.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/26/25.
//

public enum ASTNode: Equatable {
    case text(String)
    case expression(String)
    case conditional(branches: [Branch], alternative: [ASTNode]?)
    case loop(variable: String, collection: String, body: [ASTNode])
}

public struct Branch: Equatable {
    public let condition: String
    public let body: [ASTNode]
}
 
public enum Parser {
    public static func parse(_ tokens: [Token]) throws -> [ASTNode] {
        return []
    }
}

public enum ParserError: Error {
    case invalidBrackets
    case syntaxError
}

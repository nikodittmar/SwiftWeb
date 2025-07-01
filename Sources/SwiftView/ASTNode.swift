//
//  ASTNode.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/30/25.
//

enum ASTNode: Equatable, Sendable {
    case text(String)
    case expression(String)
    case conditional(branches: [Branch], alternative: [ASTNode]?)
    case loop(variable: String, collection: String, body: [ASTNode])

    mutating func addNode(_ node: ASTNode, depth: Int) throws {
        switch self {
        case .conditional(var branches, let alternative):
            if var alternative = alternative {
                try alternative.addNode(node, depth: depth)
                self = .conditional(branches: branches, alternative: alternative)
            } else {
                try branches.addNode(node, depth: depth)
                self = .conditional(branches: branches, alternative: nil)
            }
        case .loop(let variable, let collection, var body):
            try body.addNode(node, depth: depth)
            self = .loop(variable: variable, collection: collection, body: body)
        default:
            throw ParserError.syntaxError
        }
    }
    
    mutating func addBranch(_ branch: Branch, depth: Int) throws {
        if depth == 0 {
            switch self {
            case .conditional(let branches, let alternative):
                guard alternative == nil else { throw ParserError.syntaxError }
                self = .conditional(branches: branches + [branch], alternative: nil)
            default:
                throw ParserError.syntaxError
            }
        } else if depth >= 1 {
            switch self {
            case .conditional(var branches, let alternative):
                if var alternative = alternative {
                    try alternative.addBranch(branch, depth: depth - 1)
                    self = .conditional(branches: branches, alternative: alternative)
                } else {
                    try branches.addBranch(branch, depth: depth - 1)
                    self = .conditional(branches: branches, alternative: nil)
                }
            case .loop(let variable, let collection, var body):
                try body.addBranch(branch, depth: depth - 1)
                self = .loop(variable: variable, collection: collection, body: body)
            default:
                throw ParserError.syntaxError
            }
        } else {
            throw ParserError.invalidBrackets
        }
    }
    
    mutating func addAlternative(depth: Int) throws {
        if depth == 0 {
            if case let .conditional(branches, alternative) = self {
                guard alternative == nil else { throw ParserError.syntaxError }
                guard !branches.isEmpty else { throw ParserError.syntaxError }
                
                self = .conditional(branches: branches, alternative: [])
            } else {
                throw ParserError.syntaxError
            }
        } else if depth >= 1 {
            switch self {
            case .conditional(var branches, let alternative):
                if var alternative = alternative {
                    try alternative.addAlternative(depth: depth - 1)
                    self = .conditional(branches: branches, alternative: alternative)
                } else {
                    try branches.addAlternative(depth: depth - 1)
                    self = .conditional(branches: branches, alternative: nil)
                }
            case .loop(let variable, let collection, var body):
                try body.addAlternative(depth: depth - 1)
                self = .loop(variable: variable, collection: collection, body: body)
            default:
                throw ParserError.syntaxError
            }
        } else {
            throw ParserError.invalidBrackets
        }
    }
}

enum ASTNodeError: Error {
    case negativeDepth
    case syntaxError
    case invalid
}

struct Branch: Equatable {
    public var condition: String
    public var body: [ASTNode]
}

extension Array where Element == Branch {
    mutating func addNode(_ node: ASTNode, depth: Int) throws {
        guard let lastIndex = self.indices.last else { throw ParserError.invalidBrackets }
        try self[lastIndex].body.addNode(node, depth: depth)
    }
    
    mutating func addBranch(_ branch: Branch, depth: Int) throws {
        guard let lastIndex = self.indices.last else { throw ParserError.invalidBrackets }
        try self[lastIndex].body.addBranch(branch, depth: depth)
    }
    
    mutating func addAlternative(depth: Int) throws {
        guard let lastIndex = self.indices.last else { throw ParserError.invalidBrackets }
        try self[lastIndex].body.addAlternative(depth: depth)
    }
}

extension Array where Element == ASTNode {
    mutating func addNode(_ node: ASTNode, depth: Int) throws {
        if depth == 0 {
            self.append(node)
        } else if depth >= 1 {
            guard let lastIndex = self.indices.last else { throw ParserError.invalidBrackets }
            try self[lastIndex].addNode(node, depth: depth - 1)
        } else {
            throw ParserError.invalidBrackets
        }
    }
    
    mutating func addBranch(_ branch: Branch, depth: Int) throws {
        guard let lastIndex = self.indices.last else { throw ParserError.invalidBrackets }
        try self[lastIndex].addBranch(branch, depth: depth)
    }
        
    mutating func addAlternative(depth: Int) throws {
        guard let lastIndex = self.indices.last else { throw ParserError.invalidBrackets }
        try self[lastIndex].addAlternative(depth: depth)
    }
}

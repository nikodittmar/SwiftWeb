//
//  Evaluator.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/30/25.
//
import Foundation

enum EvaluatorError: Error, Equatable {
    case variableNotFound(keyPath: String)
    case typeMismatch(expected: String, actual: String)
    case notACollection(keyPath: String)
}

enum Evaluator {
    
    static func evaluate(syntaxTree: [ASTNode], context: Encodable) throws -> String {
        let contextDict = try toDictionary(context)
        return try render(ast: syntaxTree, context: contextDict)
    }

    static func evaluate(syntaxTree: [ASTNode]) throws -> String {
        return try render(ast: syntaxTree, context: [:])
    }

    private static func render(ast: [ASTNode], context: [String: Any]) throws -> String {
        var result = ""
        
        for node in ast {
            switch node {
            case .text(let string):
                result += string
                
            case .expression(let identifier):
                let value = try lookUp(keyPath: identifier, in: context)
                result += "\(value)"
                
            case .conditional(let branches, let alternative):
                var branchExecuted = false
                for branch in branches {
                    if try isTruthy(keyPath: branch.condition, in: context) {
                        result += try render(ast: branch.body, context: context)
                        branchExecuted = true
                        break
                    }
                }
                
                if !branchExecuted, let alternativeBody = alternative {
                    result += try render(ast: alternativeBody, context: context)
                }
                
            case .loop(let variable, let collectionName, let body):
                let collection = try lookUp(keyPath: collectionName, in: context)
                
                guard let array = collection as? [Any] else {
                    throw EvaluatorError.notACollection(keyPath: collectionName)
                }
                
                for item in array {
                    var loopContext = context
                    loopContext[variable] = item
                    result += try render(ast: body, context: loopContext)
                }
            }
        }
        
        return result
    }
    
    private static func lookUp(keyPath: String, in context: Any) throws -> Any {
        let keys = keyPath.split(separator: ".").map(String.init)
        var currentValue: Any = context
        
        for key in keys {
            if let dictionary = currentValue as? [String: Any] {
                guard let value = dictionary[key] else {
                    throw EvaluatorError.variableNotFound(keyPath: keyPath)
                }
                currentValue = value
            } else if key == "count", let array = currentValue as? [Any] {
                currentValue = array.count
            } else {
                throw EvaluatorError.variableNotFound(keyPath: keyPath)
            }
        }
        
        return currentValue
    }

    private static func isTruthy(keyPath: String, in context: [String: Any]) throws -> Bool {
        let value = try lookUp(keyPath: keyPath, in: context)
        
        guard let boolValue = value as? Bool else {
            throw EvaluatorError.typeMismatch(expected: "Bool", actual: String(describing: value))
        }
        
        return boolValue
    }
    
    private static func toDictionary(_ encodable: Encodable) throws -> [String: Any] {
        let data = try JSONEncoder().encode(encodable)
        guard let dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw EvaluatorError.typeMismatch(expected: "Dictionary", actual: String(describing: encodable))
        }
        return dictionary
    }
}

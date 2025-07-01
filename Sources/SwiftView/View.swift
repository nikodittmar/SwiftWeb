//
//  View.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/30/25.
//

public enum View {
    public static func fromString(_ string: String, context: Encodable) throws -> String {
        let tokens = try Tokenizer.tokenize(string)
        let syntaxTree = try Parser.parse(tokens)
        let html = try Evaluator.evaluate(syntaxTree: syntaxTree, context: context)
        
        return html
    }
}

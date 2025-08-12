//
//  Layout.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 8/10/25.
//

public final class Layout: Sendable {
    let name: String
    let layout: Layout?

    public init(name: String, layout: Layout? = nil) {
        self.name = name
        self.layout = layout
    }

    func render(loadedViews: [String: [ASTNode]], yield: String) throws -> String {
        guard let syntaxTree = loadedViews[name] else { throw ViewStoreError.viewNotFound(name: name) }

        guard let layout = layout else {
            return try Evaluator.evaluate(syntaxTree: syntaxTree, context: LayoutContext(yield: yield))
        }

        let view = try layout.render(loadedViews: loadedViews, yield: yield)

        return try Evaluator.evaluate(syntaxTree: syntaxTree, context: LayoutContext(yield: view))
    }
}

struct LayoutContext: Encodable {
    let yield: String
}
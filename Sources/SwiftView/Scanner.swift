//
//  Scanner.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/29/25.
//

/// A namespace for scanning and tokenizing template strings.
enum Scanner {
    
    /// Scans a string and converts it into an array of expression tokens.
    ///
    /// This function iterates through the input string, breaking it down into a sequence of ``ExpressionToken``s.
    /// It recognizes keywords, identifiers, and grouping symbols (`()`, `{}`). It uses whitespace
    /// (spaces, newlines, tabs) and the symbols themselves as delimiters.
    ///
    /// Any sequence of characters not identified as a keyword or a symbol is treated as an identifier.
    ///
    /// ```swift
    /// let template = "for user in users {\n  Hello, (user.name)!\n}"
    /// let tokens = Scanner.scan(template)
    /// print(tokens)
    /// // Prints:
    /// // [
    /// //   .keyword(.for), .identifier("user"), .keyword(.in), .identifier("users"),
    /// //   .leftBrace, .identifier("Hello,"), .leftParen, .identifier("user.name"),
    /// //   .rightParen, .identifier("!"), .rightBrace
    /// // ]
    /// ```
    ///
    /// - Parameter string: The raw template string to be tokenized.
    /// - Returns: An array of ``ExpressionToken``s representing the scanned string.
    static func scan(_ string: String) -> [ExpressionToken] {
        var tokens: [ExpressionToken] = []
        var word: String = ""
        
        // Appends the currently buffered `word` as either a keyword or an identifier.
        func appendWord() {
            if !word.isEmpty {
                if let keyword = Keyword(rawValue: word) {
                    tokens.append(.keyword(keyword))
                } else {
                    tokens.append(.identifier(word))
                }
                word = ""
            }
        }
        
        for char in string {
            switch char {
            case " ", "\n", "\t":
                appendWord()
            case "(":
                appendWord()
                tokens.append(.leftParen)
            case ")":
                appendWord()
                tokens.append(.rightParen)
            case "{":
                appendWord()
                tokens.append(.leftBrace)
            case "}":
                appendWord()
                tokens.append(.rightBrace)
            default:
                word.append(char)
            }
        }
        
        // Append the last word if the string doesn't end with a delimiter.
        appendWord()
        
        return tokens
    }
}

/// A token representing a distinct element within a template expression string.
enum ExpressionToken: Equatable, Hashable {
    /// A reserved keyword, such as `if` or `for`.
    case keyword(Keyword)
    
    /// A user-defined name for a variable or entity.
    case identifier(String)
    
    /// A left parenthesis character: `(`.
    case leftParen
    
    /// A right parenthesis character: `)`.
    case rightParen
    
    /// A left brace character: `{`.
    case leftBrace
    
    /// A right brace character: `}`.
    case rightBrace
}

/// A reserved keyword available in the templating language.
enum Keyword: String, Equatable {
    /// Begins a conditional block.
    case `if`
    
    /// The alternative for a conditional block.
    case `else`
    
    /// Begins a loop.
    case `for`
    
    /// Used in a `for` loop to separate the item and the collection.
    case `in`
}

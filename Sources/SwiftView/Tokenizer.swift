//
//  Tokenizer.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/26/25.
//

/// A type that provides a static method for converting a raw template string into a sequence of ``Token``s.
///
/// This tokenizer parses an input string, recognizing three types of content:
/// - Plain text and HTML.
/// - Expressions to be evaluated and printed (e.g., `<%= user.name %>`).
/// - Control flow code to be executed (e.g., `<% if user.isLoggedIn { %>`).
enum Tokenizer {
    
    /// Transforms a template string into an array of ``Token``s.
    ///
    /// The tokenizer scans the input string and breaks it down into an array of ``Token``s. Each token represents
    /// a distinct segment of the template, such as plain text, an expression to be printed, or a control flow statement.
    ///
    /// - Parameter input: The raw template string to be tokenized.
    /// - Returns: An array of ``Token``s representing the structured content of the template.
    /// - Throws: ``TokenizerError/unclosedTag`` if the input ends while a tag is still open.
    static func tokenize(_ input: String) throws -> [Token] {

        var state: State = .readingText
        var tokens: [Token] = []
        var buffer: String = ""
        
        for character in input {
            switch state {
            case .readingText:
                if character == "<" {
                    state = .sawOpeningBracket
                } else {
                    buffer.append(character)
                }
            case .sawOpeningBracket:
                if character == "%" {
                    state = .sawOpeningDelimiter
                    if buffer != "" {
                        tokens.append(.text(buffer))
                        buffer = ""
                    }
                } else {
                    state = .readingText
                    // False alarm! it was not an opening tag, add the < bracket we missed.
                    buffer.append("<")
                    buffer.append(character)
                }
            case .sawOpeningDelimiter:
                if character == "=" {
                    state = .readingTag(.expression)
                } else if character == "%" {
                    // Handle cases where the tag is immediately closed like '<%%>'
                    state = .sawClosingPercent(.code)
                } else {
                    state = .readingTag(.code)
                    buffer.append(character)
                }
            case .readingTag(let type):
                if character == "%" {
                    state = .sawClosingPercent(type)
                } else {
                    buffer.append(character)
                }
            case .sawClosingPercent(let type):
                if character == ">" {
                    state = .readingText
                    switch type {
                    case .code:
                        tokens.append(.code(buffer))
                    case .expression:
                        tokens.append(.expression(buffer))
                    }
                    buffer = ""
                } else {
                    state = .readingTag(type)
                    // False alarm! it was not an closing tag, add the % percent we missed.
                    buffer.append("%")
                    buffer.append(character)
                }
            }
        }
        
        guard case .readingText = state else {
            throw TokenizerError.unclosedTag
        }
        
        if buffer != "" {
            tokens.append(.text(buffer))
        }
        
        return tokens
    }
}

/// A representation of a single, distinct segment within a template file.
enum Token: Equatable {
    /// A segment of plain, unprocessed text or HTML.
    case text(String)
    /// A segment representing an expression to be evaluated and inserted into the surrounding HTML, found within `<%= ... %>` tags.
    case expression(String)
    /// A segment representing a block of control flow code to be executed, found within `<% ... %>` tags.
    case code(String)
}

/// An error that can occur during the tokenization process.
enum TokenizerError: Error {
    /// Thrown when the end of the input string is reached while the tokenizer is still inside an open tag.
    case unclosedTag
}

private enum State {
    case readingText
    case sawOpeningBracket
    case sawOpeningDelimiter
    case readingTag(TagType)
    case sawClosingPercent(TagType)
    
    enum TagType {
        case code
        case expression
    }
}

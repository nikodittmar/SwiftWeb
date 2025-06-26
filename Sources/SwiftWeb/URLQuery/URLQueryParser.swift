//
//  URLQueryParser.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/22/25.
//

/// A utility for parsing URL query strings.
///
/// Use this parser to break down a URL's query component into a dictionary of key-value pairs.
/// It can handle standard URL-encoded form data as well as typical query strings.
///
/// ### Usage Example:
/// ```swift
/// do {
///     let queryString = "name=John+Appleseed&email=john.appleseed%40example.com&interests=swift&interests=programming"
///     let parsedData = try URLQueryParser.parse(queryString)
///     print(parsedData)
///     // Prints: ["name": ["John Appleseed"], "email": ["john.appleseed@example.com"], "interests": ["swift", "programming"]]
/// } catch {
///     print("Failed to parse query string: \(error)")
/// }
/// ```
public enum URLQueryParser {
    
    /// Parses a URL query string into a dictionary.
    ///
    /// This method takes a string containing URL query parameters and decodes it into a dictionary
    /// where keys are the parameter names and values are arrays of their corresponding values.
    /// This handles cases where a key may appear multiple times.
    ///
    /// - Parameters:
    ///   - query: The URL query string to parse.
    ///   - mode: The parsing mode to use, which determines how characters like `+` are handled.
    ///           Defaults to `.queryString`.
    /// - Returns: A dictionary where each key corresponds to a query parameter and the value is an array of its string values.
    /// - Throws: `URLQueryParserError.invalidPercentEncoding` if the query string contains invalid percent-encoding.
    public static func parse(_ query: String, mode: URLQueryParserMode = .queryString) throws -> [String: [String]] {
        let components = query.split(separator: "&")
        
        var formData: [String:[String]] = [:]
        
        for component in components {
            if let i = component.firstIndex(of: "=") {
                // Ignore components that start with "=", such as "=value".
                if i == component.startIndex { continue }
                
                let key = try parseString(String(component[..<i]), mode: mode)
                
                let j = component.index(after: i)
                
                let value = try parseString(String(component[j...]), mode: mode)
                
                formData[key, default: []].append(value)
            } else {
                // This handles "flags," which are keys present without a value.
                if component.isEmpty { continue }
                let key = try parseString(String(component), mode: mode)
                formData[key, default: []].append("")
            }
        }
        
        return formData
    }
    
    /// Decodes a single component of a query string.
    ///
    /// This helper handles percent-decoding and, depending on the mode,
    /// converts `+` characters into spaces, which is specific to the
    /// `application/x-www-form-urlencoded` format.
    ///
    /// - Parameters:
    ///   - input: The single string component (key or value) to be decoded.
    ///   - mode: The parsing mode, which determines if `+` is treated as a space.
    /// - Returns: The decoded string.
    /// - Throws: `URLQueryParserError.invalidPercentEncoding` if the input contains an invalid percent-encoded sequence.
    private static func parseString(_ input: String, mode: URLQueryParserMode) throws -> String {
        var input = input
        
        if mode == .encodedForm {
            input = input.replacingOccurrences(of: "+", with: " ")
        }
        
        if let removed = input.removingPercentEncoding {
            return removed
        } else {
            throw URLQueryParserError.invalidPercentEncoding
        }
    }
}

/// An error that can be thrown by `URLQueryParser`.
public enum URLQueryParserError: Error {
    case invalidPercentEncoding
}

/// Defines the parsing mode for the `URLQueryParser`.
public enum URLQueryParserMode {
    /// Treats the query string as `application/x-www-form-urlencoded`, where `+` is decoded as a space.
    case encodedForm
    
    /// Treats the query string as a standard URL query string, where `+` is not treated as a space.
    case queryString
}

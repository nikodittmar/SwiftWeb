//
//  URLQueryUnflattener.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/23/25.
//

/// A utility to convert a flat URL query dictionary into a nested `URLQueryNode` structure.
///
/// This unflattener can parse complex, nested data structures encoded in URL query
/// parameters, such as those used by HTML forms. It transforms keys like `user[name]`
/// and `items[]` into a tree-like representation.
///
/// ### Usage Example:
///
/// Given a flat dictionary from a `URLQueryParser`:
/// ```swift
/// let flatQuery: [String: [String]] = [
///     "user[name]": ["John Appleseed"],
///     "user[email]": ["john@example.com"],
///     "items[]": ["Book", "Pencil"],
///     "flags[0]": ["a"],
///     "flags[1]": ["b"]
/// ]
/// ```
///
/// `URLQueryUnflattener` can transform it into a nested structure:
///
/// ```swift
/// do {
///     let nestedData = try URLQueryUnflattener.unflatten(flatQuery)
///     // nestedData now contains a structured representation:
///     // [
///     //   "user": .keyed([
///     //     "name": .singleValue("John Appleseed"),
///     //     "email": .singleValue("john@example.com")
///     //   ]),
///     //   "items": .unkeyed([.singleValue("Book"), .singleValue("Pencil")]),
///     //   "flags": .unkeyed([.singleValue("a"), .singleValue("b")])
///     // ]
/// } catch {
///     print("Error unflattering query: \(error)")
/// }
/// ```
public enum URLQueryUnflattener {
    
    /// Unflattens a dictionary of query items into a nested `URLQueryNode` structure.
    ///
    /// The method sorts the input keys to ensure that parent nodes are created before
    /// their children (e.g., `user[name]` is processed after `user`).
    ///
    /// - Parameter queryItems: A dictionary where keys are the URL-encoded paths
    ///   (e.g., "user[address][city]") and values are arrays of strings.
    /// - Returns: A dictionary representing the root of the unflattened data structure.
    /// - Throws: `URLQueryUnflattenerError` if the query keys are malformed or contain conflicts.
    public static func unflatten(_ queryItems: [String:[String]]) throws -> [String:URLQueryNode] {
        var root: [String:URLQueryNode] = [:]
        
        // Query items must first be sorted by key so that nodes are added in order of lower depth and index.
        for (queryKey, values) in queryItems.sorted(by: { $0.key < $1.key}) {
            let (key, path) = try decodeKey(queryKey)
            
            root[key] = try set(values: values, on: root[key], following: ArraySlice(path))
        }
        
        return root
    }
    
    /// Recursively traverses or builds the `URLQueryNode` tree to set the given values at a specific path.
    ///
    /// This function acts as a dispatcher, inspecting the head of the `path` and delegating to the
    /// appropriate `setKeyed` or `setUnkeyed` helper. If the path is empty, it delegates to `setLast`.
    ///
    /// - Parameters:
    ///   - values: The final string values to be set at the destination.
    ///   - node: The current `URLQueryNode` to modify. If `nil`, a new node will be created.
    ///   - path: The remaining path components to traverse. The function processes the first component and passes the rest recursively.
    /// - Returns: The new or modified `URLQueryNode`.
    /// - Throws: `URLQueryUnflattenerError` if any conflicts or errors occur during the process.
    private static func set(values: [String], on node: URLQueryNode?, following path: ArraySlice<PathComponent>) throws -> URLQueryNode {
        if !path.isEmpty {
            let currentPath = path.first!
            let remainingPath = path.dropFirst()
            
            switch currentPath {
            case .key(let key):
                return try setKeyed(key: key, values: values, on: node, following: remainingPath)
            case .index(let index):
                return try setUnkeyed(index: index, values: values, on: node, following: remainingPath)
            case .anyIndex:
                // Any index [] can only appear as the last component on the path.
                return try setLast(values: values, on: node, anyIndex: true)
            }
        } else {
            return try setLast(values: values, on: node)
        }
    }
    
    /// Handles setting a value within a keyed (dictionary-like) node.
    ///
    /// If the provided `node` is `nil`, a new keyed node is created. If it's an existing
    /// keyed node, it's updated. If it's an unkeyed node, a `typeConflict` error is thrown.
    ///
    /// - Parameters:
    ///   - key: The key within the dictionary to set.
    ///   - values: The values to pass to the next recursive step.
    ///   - node: The current `URLQueryNode`.
    ///   - path: The remaining path to traverse.
    /// - Returns: A new or updated keyed `URLQueryNode`.
    /// - Throws: `URLQueryUnflattenerError.typeConflict` if the existing node is not keyed.
    private static func setKeyed(key: String, values: [String], on node: URLQueryNode?, following path: ArraySlice<PathComponent>) throws -> URLQueryNode {
        if node == nil {
            return .keyed([ key : try set(values: values, on: nil, following: path) ])
        } else if case let .keyed(dict) = node {
            var mutableDict = dict
            mutableDict[key] = try set(values: values, on: dict[key], following: path)
            return .keyed(mutableDict)
        } else {
            throw URLQueryUnflattenerError.typeConflict
        }
    }
    
    /// Handles setting a value within an unkeyed (array-like) node.
    ///
    /// This function contains logic to either create, update, or append to an array.
    /// Because the input keys are pre-sorted, it assumes it will never have to insert into
    /// the middle of an array, only update an existing index or append to the end.
    ///
    /// - Parameters:
    ///   - index: The index within the array to set.
    ///   - values: The values to pass to the next recursive step.
    ///   - node: The current `URLQueryNode`.
    ///   - path: The remaining path to traverse.
    /// - Returns: A new or updated unkeyed `URLQueryNode`.
    /// - Throws: `URLQueryUnflattenerError.typeConflict` if the existing node is not unkeyed,
    ///   or `URLQueryUnflattenerError.invalidIndex` if the index is out of bounds.
    private static func setUnkeyed(index: Int, values: [String], on node: URLQueryNode?, following path: ArraySlice<PathComponent>) throws -> URLQueryNode {
        if node == nil {
            // Nodes are added in order of index, so if it is the first node added, the index must be 0.
            guard index == 0 else { throw URLQueryUnflattenerError.invalidIndex }
            return .unkeyed([ try set(values: values, on: nil, following: path) ])
        } else if case let .unkeyed(array) = node {
            if index < array.count {
                var mutableArray = array
                mutableArray[index] = try set(values: values, on: mutableArray[index], following: path)
                return .unkeyed(mutableArray)
            } else if index == array.count {
                // We can only add to the end of the array because nodes are added in order of index.
                return .unkeyed(array + [ try set(values: values, on: nil, following: path) ])
            } else {
                throw URLQueryUnflattenerError.invalidIndex
            }
        } else {
            throw URLQueryUnflattenerError.typeConflict
        }
    }
    
    /// Sets the terminal value(s) when the traversal path is empty. This is the base case for the recursion.
    ///
    /// This function determines whether the final node should be a single value or an array of values.
    ///
    /// - Parameters:
    ///   - values: The array of string values to set.
    ///   - node: The current node. Must be `nil`, otherwise it's a redeclaration.
    ///   - anyIndex: A boolean indicating if the path ended with `[]`, which forces an array representation.
    /// - Returns: A `URLQueryNode` representing the final value(s).
    /// - Throws: `URLQueryUnflattenerError.redeclaration` if the node already exists,
    ///   or `URLQueryUnflattenerError.emptyValue` if the values array is empty.
    private static func setLast(values: [String], on node: URLQueryNode?, anyIndex: Bool = false) throws -> URLQueryNode {
        guard node == nil else { throw URLQueryUnflattenerError.redeclaration }
        
        // Paths with [] at the end are always an array, regardless of the number of values.
        if anyIndex {
            return .unkeyed(values.map { .singleValue($0) })
        }
        
        if values.count > 1 {
            return .unkeyed(values.map { .singleValue($0) })
        } else if values.count == 1 {
            return .singleValue(values[0])
        } else {
            throw URLQueryUnflattenerError.emptyValue
        }
    }
    
    /// Parses a raw string key (e.g., "user[address][city]") into a main key and a path of components.
    ///
    /// This function uses a state machine to iterate through the string, ensuring that brackets
    /// are properly matched and structured.
    ///
    /// - Parameter queryKey: The raw string key from the URL query.
    /// - Returns: A tuple containing the main key (e.g., "user") and an array of `PathComponent`s (e.g., `[.key("address"), .key("city")]`).
    /// - Throws: `URLQueryUnflattenerError.invalidBrackets` if the key has a malformed structure.
    private static func decodeKey(_ queryKey: String) throws -> (key: String, path: [PathComponent]) {
        var key: String = ""
        var bracketSeen: Bool = false
        var openBracket: Bool = false
        var path: [PathComponent] = []
        var pathComponentString: String = ""
        
        for char in queryKey {
            if char == "[" || char == "]" {
                bracketSeen = true
                if openBracket && char == "[" || !openBracket && char == "]" {
                    throw URLQueryUnflattenerError.invalidBrackets
                }
                if char == "]" {
                    let pathComponent = PathComponent(pathComponentString)
                    if !path.isEmpty && path.last! == .anyIndex {
                        throw URLQueryUnflattenerError.invalidBrackets
                    }
                    path.append(pathComponent)
                    pathComponentString = ""
                }
                openBracket = !openBracket
            } else {
                // Characters may not appear after the path, such as "key[0]x"
                if bracketSeen && !openBracket {
                    throw URLQueryUnflattenerError.invalidBrackets
                }
                openBracket ? pathComponentString.append(char) : key.append(char)
            }
        }
        return (key: key, path: path)
    }
}

/// Represents a node in a nested, unflattened data structure.
public enum URLQueryNode: Equatable {
    /// A terminal node containing a single string value.
    case singleValue(String)
    /// An array-like node containing an ordered list of child nodes.
    case unkeyed([URLQueryNode])
    /// A dictionary-like node containing a set of key-to-node pairs.
    case keyed([String:URLQueryNode])
}

/// Represents a component in a decoded query key path.
private enum PathComponent: Equatable {
    /// A named key component, like `[name]`.
    case key(String)
    /// A numbered index component, like `[0]`.
    case index(Int)
    /// An append-style index component, like `[]`.
    case anyIndex
    
    init(_ str: String) {
        if let index = Int(str) {
            self = .index(index)
        } else if str.isEmpty {
            self = .anyIndex
        } else {
            self = .key(str)
        }
    }
}

/// An error that can occur during the query unflating process.
public enum URLQueryUnflattenerError: Error {
    /// Thrown when attempting to mix keyed and unkeyed assignments at the same level.
    /// For example, defining both `a[b]` and `a[0]`.
    case typeConflict
    /// Thrown when a query key contains mismatched or improperly nested brackets.
    /// For example, `a[b` or `a[b]]c]`.
    case invalidBrackets
    /// Thrown when a value is declared more than once at the same path.
    /// For example, defining `a[b]` twice.
    case redeclaration
    /// Thrown when a query item has an empty array of values.
    case emptyValue
    /// Thrown when an array index is out of bounds.
    /// For example, defining `a[1]` without first defining `a[0]`.
    case invalidIndex
}

//
//  DisabledCache.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 8/5/25.
//

/// A cache implementation that performs no operations, effectively disabling caching.
///
/// Use this class when you need to explicitly disable caching for a ``Database`` instance. All method calls
/// on this class are empty and have no side effects, providing a "null object" that fulfills the ``Cache``
/// protocol without storing any data.
public final class DisabledCache: Cache {

    /// Creates a new instance of the disabled cache.
    public init() {}

    /// Immediately returns `nil` without performing any cache lookup.
    ///
    /// - Parameter key: The key for the model. This parameter is ignored.
    /// - Returns: Always returns `nil`.
    public func get<T>(_ key: String) async throws -> T? where T : Model {
        return nil
    }

    /// Performs no operation and does not store the value.
    ///
    /// - Parameters:
    ///   - key: The key for the model. This parameter is ignored.
    ///   - value: The model to store. This parameter is ignored.
    public func set<T>(_ key: String, to value: T) async throws where T : Model {
        // This cache does nothing, so the method is empty.
    }

    /// Performs no operation.
    ///
    /// - Parameter key: The key of the item to delete. This parameter is ignored.
    public func delete(_ key: String) async throws {
        // This cache does nothing, so the method is empty.
    }
}
//
//  Cache.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 8/11/25.
//
import Foundation

/// A protocol that defines a standardized interface for a key-value cache.
///
/// Conforming types are responsible for storing, retrieving, and deleting `Model` objects in a thread-safe manner.
/// This abstraction allows different caching strategies (e.g., in-memory LRU, Redis, file-based) to be used
/// interchangeably within the application.
public protocol Cache<Key, Value>: Sendable {
    associatedtype Key: Hashable & Sendable
    associatedtype Value: Sendable

    /// Retrieves a model from the cache for a given key.
    ///
    /// - Parameter key: The unique key for the model.
    /// - Returns: The cached model instance cast to the expected type `T`, or `nil` if the key is not found.
    func get(_ key: Key) async throws -> Value?

    /// Stores or updates a model in the cache for a given key, with an optional expiration.
    ///
    /// - Parameters:
    ///   - key: The unique key to store the value under.
    ///   - value: The model instance to cache.
    func set(_ key: Key, to value: Value) async throws

    /// Deletes a model from the cache for a given key.
    ///
    /// If no value exists for the key, this method should have no effect.
    ///
    /// - Parameter key: The unique key of the item to delete.
    func delete(_ key: Key) async throws
}
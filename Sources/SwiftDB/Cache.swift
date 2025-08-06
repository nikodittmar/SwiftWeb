//
//  Database.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 8/5/25.
//
import Foundation

/// A protocol that defines a standardized interface for a key-value cache.
///
/// Conforming types are responsible for storing, retrieving, and deleting `Model` objects in a thread-safe manner.
/// This abstraction allows different caching strategies (e.g., in-memory LRU, Redis, file-based) to be used
/// interchangeably within the application.
public protocol Cache: Sendable {

    /// Retrieves a model from the cache for a given key.
    ///
    /// - Parameter key: The unique key for the model.
    /// - Returns: The cached model instance cast to the expected type `T`, or `nil` if the key is not found.
    func get<T: Model>(_ key: String) async throws -> T?

    /// Stores or updates a model in the cache for a given key, with an optional expiration.
    ///
    /// - Parameters:
    ///   - key: The unique key to store the value under.
    ///   - value: The model instance to cache.
    func set<T: Model>(_ key: String, to value: T) async throws

    /// Deletes a model from the cache for a given key.
    ///
    /// If no value exists for the key, this method should have no effect.
    ///
    /// - Parameter key: The unique key of the item to delete.
    func delete(_ key: String) async throws
}
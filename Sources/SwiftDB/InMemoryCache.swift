//
//  InMemoryCache.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 8/5/25.
//

/// An in-memory, thread-safe cache that evicts the least recently used items once it reaches its capacity.
///
/// Use this cache to store frequently accessed `Model` objects to reduce database load and improve
/// application performance. The cache automatically handles concurrent access and manages its size based on an LRU (Least Recently Used) policy.
public actor InMemoryCache: Cache {

    private class LRUNode {
        let key: String
        var value: Model
        var next: LRUNode?
        var prev: LRUNode?

        init(key: String, value: Model) {
            self.key = key
            self.value = value
        }
    }

    private let capacity: Int
    private var cache: [String: LRUNode] = [:]
    private let head: LRUNode
    private let tail: LRUNode

    /// Initializes a new in-memory LRU cache.
    ///
    /// - Parameter capacity: The maximum number of items the cache can store before it starts evicting the
    ///   least recently used items. Defaults to `1024`. This value must be greater than zero.
    public init(capacity: Int = 1024) {
        guard capacity > 0 else { preconditionFailure("InMemoryCache cannot be initialized with negative or zero capacity!") }
        self.capacity = capacity

        struct DummyModel: Model { static let schema: String = ""; var id: Int? }
        self.head = LRUNode(key: "", value: DummyModel())
        self.tail = LRUNode(key: "", value: DummyModel())

        self.head.next = self.tail
        self.tail.prev = self.head
    }

    /// Retrieves a model from the cache for a given key.
    ///
    /// If a value is found, it is marked as the most recently used item.
    ///
    /// - Parameter key: The unique key for the model.
    /// - Returns: The cached model instance cast to the expected type `T`, or `nil` if the key is not found
    ///   or the type cast fails.
    public func get<T: Model>(_ key: String) async throws -> T? {
        guard let node = self.cache[key] else { return nil }
        guard let value = node.value as? T else { return nil }

        self.remove(node: node)
        self.addToFront(node: node)

        return value
    }

    /// Stores or updates a model in the cache for a given key.
    ///
    /// If the key already exists, its value is updated. In both new and update cases, the item is marked
    /// as the most recently used. If adding a new item exceeds the cache's capacity, the least recently used item is removed.
    ///
    /// - Parameters:
    ///   - key: The unique key to store the value under.
    ///   - value: The model instance to cache.
    ///   - expiration: This parameter is ignored by `InMemoryCache`.
    public func set<T: Model>(_ key: String, to value: T, expiration: Duration? = nil) async throws where T : Model {

        if let node = self.cache[key] {
            self.remove(node: node)
            self.addToFront(node: node)
            node.value = value
        } else {

            if self.cache.count >= capacity {
                guard let toEvict = self.tail.prev else { throw InMemoryCacheError.evictionError }
                self.remove(node: toEvict)
                
                self.cache.removeValue(forKey: toEvict.key)
            }

            let node = LRUNode(key: key, value: value)
            self.addToFront(node: node)
            self.cache[key] = node
        }
    }

    /// Deletes a model from the cache for a given key.
    ///
    /// If no value exists for the key, this method has no effect.
    ///
    /// - Parameter key: The unique key of the item to delete.
    public func delete(_ key: String) async throws {
        if let node = self.cache[key] {
            self.remove(node: node)
            self.cache.removeValue(forKey: key)
        }
    }

    private func remove(node: LRUNode) {
        node.prev?.next = node.next
        node.next?.prev = node.prev

        node.next = nil
        node.prev = nil
    }

    private func addToFront(node: LRUNode) {
        node.next = self.head.next
        node.prev = self.head
        self.head.next = node
        node.next?.prev = node
    }
}

/// An error that can occur during cache operations.
enum InMemoryCacheError: Error {
    /// Thrown if an error occurs during the eviction process.
    case evictionError
}
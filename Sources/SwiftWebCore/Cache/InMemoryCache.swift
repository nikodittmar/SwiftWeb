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
public actor InMemoryCache<Key: Hashable & Sendable, Value: Sendable>: Cache {

    private class LRUNode {
        var next: LRUNode? 
        var prev: LRUNode?
        let key: Key?

        init(key: Key? = nil) {
            self.key = key
        }
    }

    private class ValueNode: LRUNode {
        var value: Value

        init(key: Key, value: Value) {
            self.value = value
            super.init(key: key)
        }
    }

    private let capacity: Int
    private var cache: [Key: ValueNode] = [:]
    private let head: LRUNode = LRUNode()
    private let tail: LRUNode = LRUNode()

    /// Initializes a new in-memory LRU cache.
    ///
    /// - Parameter capacity: The maximum number of items the cache can store before it starts evicting the
    ///   least recently used items. Defaults to `1024`. This value must be greater than zero.
    public init(capacity: Int = 1024) {
        guard capacity > 0 else { preconditionFailure("InMemoryCache capacity must be greater than zero.") }
        self.capacity = capacity

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
    public func get(_ key: Key) async throws -> Value? {
        guard let node = self.cache[key] else { return nil }

        self.remove(node: node)
        self.addToFront(node: node)

        return node.value
    }

    /// Stores or updates a model in the cache for a given key.
    ///
    /// If the key already exists, its value is updated. In both new and update cases, the item is marked
    /// as the most recently used. If adding a new item exceeds the cache's capacity, the least recently used item is removed.
    ///
    /// - Parameters:
    ///   - key: The unique key to store the value under.
    ///   - value: The model instance to cache.
    public func set(_ key: Key, to value: Value) async throws {

        if let node = self.cache[key] {
            self.remove(node: node)
            self.addToFront(node: node)
            node.value = value
        } else {

            if self.cache.count >= capacity {
                guard let lru = self.tail.prev, let key = lru.key else { 
                    throw SwiftWebError(type: .internalServerError, reason: "Cache eviction failed: could not find an LRU node to evict.")
                }
                self.remove(node: lru)
                
                self.cache.removeValue(forKey: key)
            }

            let node = ValueNode(key: key, value: value)
            self.addToFront(node: node)
            self.cache[key] = node
        }
    }

    /// Deletes a model from the cache for a given key.
    ///
    /// If no value exists for the key, this method has no effect.
    ///
    /// - Parameter key: The unique key of the item to delete.
    public func delete(_ key: Key) async throws {
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
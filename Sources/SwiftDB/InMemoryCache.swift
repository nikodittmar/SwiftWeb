//
//  InMemoryCache.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 8/5/25.
//

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

    public init(capacity: Int = 1024) {
        guard capacity > 0 else { preconditionFailure("InMemoryCache cannot be initialized with negative or zero capacity!") }
        self.capacity = capacity

        struct DummyModel: Model { static let schema: String = ""; var id: Int? }
        self.head = LRUNode(key: "", value: DummyModel())
        self.tail = LRUNode(key: "", value: DummyModel())

        self.head.next = self.tail
        self.tail.prev = self.head
    }

    public func get<T: Model>(_ key: String) async throws -> T? {
        guard let node = self.cache[key] else { return nil }
        guard let value = node.value as? T else { return nil }

        self.remove(node: node)
        self.addToFront(node: node)

        return value
    }

    public func set<T: Model>(_ key: String, to value: T) async throws where T : Model {

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

enum InMemoryCacheError: Error {
    case evictionError
}
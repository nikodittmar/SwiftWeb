//
//  InMemoryCacheTests.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 7/5/25.
//

import Testing
@testable import SwiftWebCore
import SwiftDB

@Suite struct InMemoryCacheTests {

    struct TestModel: Model {
        static let schema: String = "test"

        var id: Int?
        var name: String
    }

    struct SecondTestModel: Model {
        static let schema: String = "test"

        var id: Int?
        var title: String
    }

    @Test func test_InMemoryCache_SetAndGet_IsValid() async throws {
        let cache = InMemoryCache<String, Model>()
        try await cache.set("test", to: TestModel(id: 1, name: "test"))
        let retreived: TestModel? = try await cache.get("test") as? TestModel

        #expect(retreived != nil)
        #expect(retreived?.id == 1)
        #expect(retreived?.name == "test")
    }

    @Test func test_InMemoryCache_Missing_ReturnsNil() async throws {
        let cache = InMemoryCache<String, Model>()
        let retreived: TestModel? = try await cache.get("test") as? TestModel

        #expect(retreived == nil)
    }

    @Test func test_InMemoryCache_Eviction_IsValid() async throws {
        let cache = InMemoryCache<String, Model>(capacity: 2)
        try await cache.set("test_1", to: TestModel(id: 1, name: "test_1"))
        try await cache.set("test_2", to: TestModel(id: 2, name: "test_2"))
        try await cache.set("test_3", to: TestModel(id: 3, name: "test_3"))

        let retreived_1: TestModel? = try await cache.get("test_1") as? TestModel
        let retreived_2: TestModel? = try await cache.get("test_2") as? TestModel
        let retreived_3: TestModel? = try await cache.get("test_3") as? TestModel


        #expect(retreived_1 == nil)

        #expect(retreived_2 != nil)
        #expect(retreived_2?.id == 2)
        #expect(retreived_2?.name == "test_2")

        #expect(retreived_3 != nil)
        #expect(retreived_3?.id == 3)
        #expect(retreived_3?.name == "test_3")
    }

    @Test func test_InMemoryCache_LRUEviction_IsValid() async throws {
        let cache = InMemoryCache<String, Model>(capacity: 2)
        try await cache.set("test_1", to: TestModel(id: 1, name: "test_1"))
        try await cache.set("test_2", to: TestModel(id: 2, name: "test_2"))

        let retreived_1: TestModel? = try await cache.get("test_1") as? TestModel

        try await cache.set("test_3", to: TestModel(id: 3, name: "test_3"))

        let retreived_2: TestModel? = try await cache.get("test_2") as? TestModel
        let retreived_3: TestModel? = try await cache.get("test_3") as? TestModel


        #expect(retreived_2 == nil)

        #expect(retreived_1 != nil)
        #expect(retreived_1?.id == 1)
        #expect(retreived_1?.name == "test_1")

        #expect(retreived_3 != nil)
        #expect(retreived_3?.id == 3)
        #expect(retreived_3?.name == "test_3")
    }

    @Test func test_InMemoryCache_Update_IsValid() async throws {
        let cache = InMemoryCache<String, Model>()
        try await cache.set("test", to: TestModel(id: 1, name: "test_1"))
        try await cache.set("test", to: TestModel(id: 2, name: "test_2"))

        let retreived: TestModel? = try await cache.get("test") as? TestModel

        #expect(retreived != nil)
        #expect(retreived?.id == 2)
        #expect(retreived?.name == "test_2")
    }

    @Test func test_InMemoryCache_Delete_IsValid() async throws {
        let cache = InMemoryCache<String, Model>()
        try await cache.set("test", to: TestModel(id: 1, name: "test"))
        try await cache.delete("test")
        let retreived: SecondTestModel? = try await cache.get("test") as? SecondTestModel

        #expect(retreived == nil)
    }

    @Test func test_InMemoryCache_GetWithIncorrectType_IsValid() async throws {
        let cache = InMemoryCache<String, Model>()
        try await cache.set("test", to: TestModel(id: 1, name: "test"))
        let retreived: SecondTestModel? = try await cache.get("test") as? SecondTestModel

        #expect(retreived == nil)
    }
}
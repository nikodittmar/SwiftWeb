//
//  Model.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/21/25.
//
import Foundation
import PostgresNIO
import SwiftWebCore

public enum QueryOperator: String {
    case equals = "="
    case notEquals = "!="
    case greaterThan = ">"
    case lessThan = "<"
    case greaterThanOrEquals = ">="
    case lessThanOrEquals = "<="
}

public protocol Model: Codable, Sendable {
    static var schema: String { get }
    var id: Int? { get set }
}

extension Model {
    public func getId() throws -> Int {
        guard let id = self.id else {
            throw SwiftWebError(type: .preconditionFailed, reason: "Attempted to get ID from a model that has not been saved yet.")
        }
        return id
    }

    public mutating func save(on db: Database) async throws {
        if let id = self.id {
            try await self.performUpdate(id: id, on: db)
        } else {
            try await self.performInsert(on: db)
        }
    }

    private mutating func performInsert(on db: Database) async throws {
        let properties = try PostgresEncoder().encode(self).filter { $0.name != "id" }
        
        let columnSQL = properties.map({ "\"\($0.name)\"" }).joined(separator: ", ")
        let placeholderSQL = properties.enumerated().map({ (index, _) -> String in
            return "$\(index + 1)"
        }).joined(separator: ", ")
        
        let sql = "INSERT INTO \"\(Self.schema)\" (\(columnSQL)) VALUES (\(placeholderSQL)) RETURNING *"
        
        var bindings = PostgresBindings(capacity: properties.count)
        for property in properties {
            guard let value = property.value else { 
                throw SwiftWebError(type: .internalServerError, reason: "Failed to save model of type '\(Self.self)' because a property was unexpectedly nil.")
            }
            try bindings.append(value)
        }
        
        let query = PostgresQuery(unsafeSQL: sql, binds: bindings)

        guard let row = try await db.query(query).collect().first else {
            throw SwiftWebError(type: .internalServerError, reason: "Failed to save model of type '\(Self.self)': Database did not return the saved row.")
        }

        self = try PostgresDecoder().decode(Self.self, from: row.makeRandomAccess())
        
        if let id = self.id {
            let key = Self.cacheKey(id: id)
            try await db.cache.set(key, to: self)
        }
    }

    private mutating func performUpdate(id: Int, on db: Database) async throws {
        let properties = try PostgresEncoder().encode(self).filter { $0.name != "id" }
        
        let setSQL = properties.enumerated().map { (index, property) in
            let placeholder = "$\(index + 1)"
            return "\"\((property.name))\" = \(placeholder)"
        }.joined(separator: ", ")
        
        let sql = "UPDATE \"\(Self.schema)\" SET \(setSQL) WHERE id = $\(properties.count + 1) RETURNING *"
        
        var bindings = PostgresBindings(capacity: properties.count + 1)
        for property in properties {
            guard let value = property.value else { 
                throw SwiftWebError(type: .internalServerError, reason: "Failed to update model of type '\(Self.self)' because a property was unexpectedly nil.") 
            }
            try bindings.append(value)
        }
        bindings.append(id)
        
        let query = PostgresQuery(unsafeSQL: sql, binds: bindings)

        guard let row = try await db.query(query).collect().first else {
            throw SwiftWebError(type: .notFound, reason: "Failed to update model of type '\(Self.self)' with ID \(id): Row not found.")
        }

        self = try PostgresDecoder().decode(Self.self, from: row.makeRandomAccess())

        let key: String = Self.cacheKey(id: id)
        try await db.cache.set(key, to: self)
    }

    public func destroy(on db: Database) async throws {
        let id = try self.getId()
        try await Self.destroy(id: id, on: db)
    }

    public static func destroy(id: Int, on db: Database) async throws {
        var bindings = PostgresBindings(capacity: 1)
        bindings.append(id)
        _ = try await db.query(PostgresQuery(unsafeSQL: "DELETE FROM \"\(Self.schema)\" WHERE id = $1", binds: bindings))
        
        let key: String = Self.cacheKey(id: id)
        try await db.cache.delete(key)
    }
    
    public static func all(on db: Database) async throws -> [Self] {
        let query = PostgresQuery(unsafeSQL: "SELECT * FROM \"\(Self.schema)\"")
        let rows = try await db.query(query).collect()
                
        let decoder = PostgresDecoder()
        
        return try rows.map { row in
            try decoder.decode(Self.self, from: row.makeRandomAccess())
        }
    }
    
    public static func find(id: Int, on db: Database) async throws -> Self {
        let key: String = Self.cacheKey(id: id)
        if let model = try? await db.cache.get(key) as? Self {
            return model
        }

        var bindings = PostgresBindings(capacity: 1)
        bindings.append(id)
        
        let query = PostgresQuery(unsafeSQL: "SELECT * FROM \"\(Self.schema)\" WHERE id = $1 LIMIT 1", binds: bindings)
        
        guard let row = try await db.query(query).collect().first else {
            throw SwiftWebError(type: .notFound, reason: "A model of type '\(Self.self)' with ID \(id) was not found.")
        }

        let model = try PostgresDecoder().decode(Self.self, from: row.makeRandomAccess())
        try await db.cache.set(key, to: model)
        return model
    }

    public static func first(where column: String, _ op: QueryOperator, _ value: PostgresEncodable, on db: Database) async throws -> Self {
        let sql = "SELECT * FROM \"\(Self.schema)\" WHERE \"\(column)\" \(op.rawValue) $1 LIMIT 1"
        
        var bindings = PostgresBindings(capacity: 1)
        try bindings.append(value)
        
        let query = PostgresQuery(unsafeSQL: sql, binds: bindings)
        
        guard let row = try await db.query(query).collect().first else {
            throw SwiftWebError(type: .notFound, reason: "A model of type '\(Self.self)' was not found where `\(column)` \(op.rawValue) \(String(describing: value))")
        }
        
        let model = try PostgresDecoder().decode(Self.self, from: row.makeRandomAccess())
        
        if let id = model.id {
            let key = Self.cacheKey(id: id)
            try await db.cache.set(key, to: model)
        }
        
        return model
    }

    public static func find(where column: String, _ op: QueryOperator, _ value: PostgresEncodable, on db: Database) async throws -> [Self] {
        let sql = "SELECT * FROM \"\(Self.schema)\" WHERE \"\(column)\" \(op.rawValue) $1"

        var bindings = PostgresBindings(capacity: 1)
        try bindings.append(value)

        let query = PostgresQuery(unsafeSQL: sql, binds: bindings)
        let rows = try await db.query(query).collect()
        
        let decoder = PostgresDecoder()
        let models = try rows.map { row in
            try decoder.decode(Self.self, from: row.makeRandomAccess())
        }

        for model in models {
            if let id = model.id {
                let key = Self.cacheKey(id: id)
                try await db.cache.set(key, to: model)
            }
        }
        
        return models
    }

    public static func findBy(_ column: String, is value: PostgresEncodable, on db: Database) async throws -> Self {
        return try await first(where: column, .equals, value, on: db)
    }
    
    public static func find(where column: String, is value: PostgresEncodable, on db: Database) async throws -> [Self] {
        return try await find(where: column, .equals, value, on: db)
    }

    private static func cacheKey(id: Int) -> String {
        return "\(Self.schema):\(id)"
    }
}

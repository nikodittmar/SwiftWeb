//
//  Model.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/21/25.
//
import Foundation
import PostgresNIO
import SwiftWebCore

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
        let properties = try PostgresEncoder().encode(self).filter { $0.name != "id" }
        
        let columnSQL = properties.map({ "\"\($0.name)\"" }).joined(separator: ", ")
        let placeholderSQL = properties.enumerated().map({ (index, column) in
            if column.type == .jsonb {
                return "$\(index + 1)::jsonb"
            } else {
                return "$\(index + 1)"
            }
        }).joined(separator: ", ")
        
        let SQLString = "INSERT INTO \"\(Self.schema)\" (\(columnSQL)) VALUES (\(placeholderSQL)) RETURNING *"
        
        var bindings = PostgresBindings(capacity: properties.count)
        
        for property in properties {
            guard let value = property.value else { 
                throw SwiftWebError(type: .internalServerError, reason: "Failed to save model of type '\(Self.self)' because a property was unexpectedly nil.")
            }
            try bindings.append(value)
        }
        
        let query = PostgresQuery(unsafeSQL: SQLString, binds: bindings)

        guard let row = try await db.query(query).collect().first else {
            throw SwiftWebError(type: .internalServerError, reason: "Failed to save model of type '\(Self.self)': Database did not return the saved row.")
        }

        let saved = try PostgresDecoder().decode(Self.self, from: row.makeRandomAccess())
        
        if let id = saved.id {
            let key = Self.cacheKey(id: id)
            try await db.cache.set(key, to: saved)
        }
    
        self.id = saved.id
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

    public mutating func update(on db: Database) async throws {
        let id = try self.getId()
        try await self.update(id: id, on: db)
    }

    public mutating func update(id: Int, on db: Database) async throws {
        let properties = try PostgresEncoder().encode(self).filter { $0.name != "id" }
        
        let columnSQL = properties.map({ "\"\($0.name)\"" }).joined(separator: ", ")
        let placeholderSQL = properties.enumerated().map({ (index, column) in
            if column.type == .jsonb {
                return "$\(index + 1)::jsonb"
            } else {
                return "$\(index + 1)"
            }
        }).joined(separator: ", ")
        
        let SQLString = "UPDATE \"\(Self.schema)\" SET (\(columnSQL)) = (\(placeholderSQL)) WHERE id = $\(properties.count + 1) RETURNING *"
        
        var bindings = PostgresBindings(capacity: properties.count + 1)
        
        for property in properties {
            guard let value = property.value else { 
                throw SwiftWebError(type: .internalServerError, reason: "Failed to update model of type '\(Self.self)' because a property was unexpectedly nil.") 
            }
            try bindings.append(value)
        }

        bindings.append(id)
        
        let query = PostgresQuery(unsafeSQL: SQLString, binds: bindings)

        _ = try await db.query(query)

        self.id = id

        let key: String = Self.cacheKey(id: id)
        try await db.cache.set(key, to: self)
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
        if let model: Self = try? await db.cache.get(key) as? Self {
            return model
        }

        var bindings = PostgresBindings(capacity: 1)
        bindings.append(id)
        
        let query = PostgresQuery(unsafeSQL: "SELECT * FROM \(Self.schema) WHERE id = $1 LIMIT 1", binds: bindings)
        
        let decoder = PostgresDecoder()
        
        guard let row = try await db.query(query).collect().first else {
            throw SwiftWebError(type: .notFound, reason: "A model of type '\(Self.self)' with ID \(id) was not found.")
        }

        let model = try decoder.decode(Self.self, from: row.makeRandomAccess())

        try await db.cache.set(key, to: model)

        return model
    }

    private static func cacheKey(id: Int) -> String {
        return "\(Self.schema):\(id)"
    }
}
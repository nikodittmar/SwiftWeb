//
//  Model.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/21/25.
//
import Foundation
import PostgresNIO

public protocol Model: Codable, Sendable {
    static var schema: String { get }
    var id: Int? { get }
}

extension Model {
    public func save(on db: Database) async throws -> Self {
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
            guard let value = property.value else { throw ModelError.saveFailed }
            try bindings.append(value)
        }
        
        let query = PostgresQuery(unsafeSQL: SQLString, binds: bindings)

        guard let row = try await db.query(query).collect().first else {
            throw ModelError.saveFailed
        }
    
        return try PostgresDecoder().decode(Self.self, from: row.makeRandomAccess())
    }

    public func destroy(on db: Database) async throws {
        guard let id = self.id else { throw ModelError.missingId }
        var bindings = PostgresBindings(capacity: 1)
        bindings.append(id)
        _ = try await db.query(PostgresQuery(unsafeSQL: "DELETE FROM \"\(Self.schema)\" WHERE id = $1", binds: bindings))
    }

    public func update(on db: Database) async throws {
        guard let id = self.id else { throw ModelError.missingId }

        let properties = try PostgresEncoder().encode(self).filter { $0.name != "id" }
        
        let columnSQL = properties.map({ "\"\($0.name)\"" }).joined(separator: ", ")
        let placeholderSQL = properties.enumerated().map({ (index, column) in
            if column.type == .jsonb {
                return "$\(index + 1)::jsonb"
            } else {
                return "$\(index + 1)"
            }
        }).joined(separator: ", ")
        
        let SQLString = "UPDATE \"\(Self.schema)\" SET (\(columnSQL)) = (\(placeholderSQL)) WHERE id = $\(properties.count + 1)"
        
        var bindings = PostgresBindings(capacity: properties.count + 1)
        
        for property in properties {
            guard let value = property.value else { throw ModelError.saveFailed }
            try bindings.append(value)
        }

        bindings.append(id)
        
        let query = PostgresQuery(unsafeSQL: SQLString, binds: bindings)

        _ = try await db.query(query)
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
        var bindings = PostgresBindings(capacity: 1)
        bindings.append(id)
        
        let query = PostgresQuery(unsafeSQL: "SELECT * FROM \(Self.schema) WHERE id = $1 LIMIT 1", binds: bindings)
        
        let decoder = PostgresDecoder()
        
        if let row = try await db.query(query).collect().first {
            return try decoder.decode(Self.self, from: row.makeRandomAccess())
        }
        throw ModelError.notFound
    }
}

public enum ModelError: Error {
    case notFound
    case saveFailed
    case missingId
}

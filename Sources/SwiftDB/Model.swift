//
//  Model.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/21/25.
//
import PostgresNIO

public protocol Model: Codable, Sendable {
    static var schema: String { get }
    var id: Int? { get }
}

extension Model {
    func save(on db: Database) async throws {
        let mirror = Mirror(reflecting: self)
        
        let properties = mirror.children.filter { $0.label != "id" }
        
        let columnSQL = properties.compactMap({ $0.label }).joined(separator: ", ")
        let placeholderSQL = (1...properties.count).map({ "$\($0)" }).joined(separator: ", ")
        
        let SQLString = "INSERT INTO \(Self.schema) (\(columnSQL)) VALUES (\(placeholderSQL));"
        
        var bindings = PostgresBindings(capacity: properties.count)
        
        for property in properties {
            guard let value = property.value as? PostgresEncodable else {
                preconditionFailure("Property '\(property.label ?? "unknown")' does not conform to PostgresEncodable.")
            }
            try bindings.append(value)
        }
        
        let query = PostgresQuery(unsafeSQL: SQLString, binds: bindings)
        try await db.client.query(query)
    }
    
    static func all(on db: Database) async throws -> [Self] {
        let query = PostgresQuery(unsafeSQL: "SELECT * FROM \(Self.schema)")
        let rows = try await db.client.query(query).collect()
        
        var records: [Self] = []
        
        let decoder = PostgresDecoder()
        
        for row in rows.map({ PostgresRandomAccessRow($0) }) {
            records.append(try decoder.decode(Self.self, from: row))
        }
        return records
    }
    
    static func find(on db: Database, id: Int) async throws -> Self {
        let query = PostgresQuery(unsafeSQL: "SELECT * FROM \(Self.schema) WHERE id=\(id) LIMIT 1")
        let decoder = PostgresDecoder()
        
        if let row = try await db.client.query(query).collect().first {
            return try decoder.decode(Self.self, from: row.makeRandomAccess())
        }
        throw QueryError.notFound
    }
}

public enum QueryError: Error {
    case notFound
}

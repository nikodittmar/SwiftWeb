//
//  SchemaBuilder.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 7/18/25.
//

import PostgresNIO

public enum SchemaAction {
    case createTable(TableDefinition)
    case dropTable(TableDefinition)
    case addColumn(ColumnDefinition, to: String)
    case dropColumn(ColumnDefinition, from: String)

    func upSql() -> String {
        switch self {
        case .createTable(let definition):
            let columnsSQL = definition.columns.map { "\"\($0.name)\" \($0.type)" }.joined(separator: ", ")
            return "CREATE TABLE IF NOT EXISTS \"\(definition.name)\" (\(columnsSQL))"
        case .dropTable(let definition):
            return "DROP TABLE IF EXISTS \"\(definition.name)\""
        case .addColumn(let definition, let tableName):
            return "ALTER TABLE IF EXISTS \"\(tableName)\" ADD COLUMN \"\(definition.name)\" \(definition.type)"
        case .dropColumn(let definition, let tableName):
            return "ALTER TABLE IF EXISTS \"\(tableName)\" DROP COLUMN \"\(definition.name)\""
        }
    }

    func downSql() -> String {
        switch self {
        case .createTable(let definition):
            return "DROP TABLE IF EXISTS \"\(definition.name)\""
        case .dropTable(let definition):
            let columnsSQL = definition.columns.map { "\"\($0.name)\" \($0.type)" }.joined(separator: ", ")
            return "CREATE TABLE IF NOT EXISTS \"\(definition.name)\" (\(columnsSQL))"
        case .addColumn(let definition, let tableName):
            return "ALTER TABLE IF EXISTS \"\(tableName)\" DROP COLUMN \"\(definition.name)\""
        case .dropColumn(let definition, let tableName):
            return "ALTER TABLE IF EXISTS \"\(tableName)\" ADD COLUMN \"\(definition.name)\" \(definition.type)"
        }
    }
}

public struct TableDefinition {
    fileprivate let name: String
    var columns: [ColumnDefinition] = [.init(name: "id", type: "SERIAL PRIMARY KEY")]

    public mutating func column(_ name: String, type: String) {
        self.columns.append(.init(name: name, type: type))
    }
}

public struct ColumnDefinition {
    let name: String
    var type: String
}

public final class SchemaBuilder {
    private(set) var actions: [SchemaAction] = []

    public func createTable(_ name: String, _ build: (inout TableDefinition) -> Void) {
        var table = TableDefinition(name: name)
        build(&table)
        self.actions.append(.createTable(table))
    }

    public func dropTable(_ name: String, _ build: (inout TableDefinition) -> Void) {
        var table = TableDefinition(name: name)
        build(&table)
        self.actions.append(.dropTable(table))
    }

    public func addColumn(_ name: String, type: String, table: String) {
        self.actions.append(.addColumn(.init(name: name, type: type), to: table))
    }

    public func dropColumn(_ name: String, type: String, table: String) {
        self.actions.append(.dropColumn(.init(name: name, type: type), from: table))
    }
}

extension Migration {
    public static func up(on connection: PostgresConnection) async throws {
        let builder = SchemaBuilder()
        change(builder: builder)

        for action in builder.actions {
            _ = try await connection.query(action.upSql()).get()
        }
    }

    public static func down(on connection: PostgresConnection) async throws {
        let builder = SchemaBuilder()
        change(builder: builder)

        for action in builder.actions.reversed() {
            _ = try await connection.query(action.downSql()).get()
        }
    }
}


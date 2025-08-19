//
//  SchemaBuilder.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 8/18/25.
//

import PostgresNIO
import Foundation

public enum PostgresDataType {
    case serialPrimaryKey
    case bigSerialPrimaryKey
    case integer
    case bigInt
    case text
    case string(length: Int?)
    case timestamp
    case boolean
    case uuid
    
    public static var string: PostgresDataType {
        return .string(length: nil)
    }
    
    var sqlRepresentation: String {
        switch self {
        case .serialPrimaryKey: return "SERIAL PRIMARY KEY"
        case .bigSerialPrimaryKey: return "BIGSERIAL PRIMARY KEY"
        case .integer: return "INTEGER"
        case .bigInt: return "BIGINT"
        case .text: return "TEXT"
        case .string(let length):
            if let length = length {
                return "VARCHAR(\(length))"
            }
            return "VARCHAR"
        case .timestamp: return "TIMESTAMP"
        case .boolean: return "BOOLEAN"
        case .uuid: return "UUID"
        }
    }
}

public enum ForeignKeyAction: String {
    case noAction = "NO ACTION"
    case restrict = "RESTRICT"
    case cascade = "CASCADE"
    case setNull = "SET NULL"
    case setDefault = "SET DEFAULT"
}

public struct ColumnDefinition {
    public let name: String
    public let type: PostgresDataType
    public let null: Bool
    public let defaultValue: String?

    public init(name: String, type: PostgresDataType, null: Bool, defaultValue: String? = nil) {
        self.name = name
        self.type = type
        self.null = null
        self.defaultValue = defaultValue
    }
    
    var sqlRepresentation: String {
        if type.sqlRepresentation.contains("PRIMARY KEY") {
            return "\"\((name))\" \(type.sqlRepresentation)"
        }
        let nullability = null ? "" : " NOT NULL"
        let defaultSQL = defaultValue.map { " DEFAULT \($0)" } ?? ""
        return "\"\((name))\" \(type.sqlRepresentation)\(nullability)\(defaultSQL)"
    }
}

public struct ForeignKeyConstraint {
    public let column: String
    public let referencesTable: String
    public let referencesColumn: String
    public let onDelete: ForeignKeyAction
    public let onUpdate: ForeignKeyAction
    
    var sqlRepresentation: String {
        return "FOREIGN KEY (\"\(column)\") REFERENCES \"\(referencesTable)\"(\"\(referencesColumn)\") ON DELETE \(onDelete.rawValue) ON UPDATE \(onUpdate.rawValue)"
    }
}

public struct IndexDefinition {
    public let tableName: String
    public let columns: [String]
    public let isUnique: Bool
    public let name: String

    public init(tableName: String, columns: [String], isUnique: Bool = false, name: String? = nil) {
        self.tableName = tableName
        self.columns = columns
        self.isUnique = isUnique
        self.name = name ?? "idx_\(tableName)_\(columns.joined(separator: "_"))"
    }
}

public struct TableDefinition {
    fileprivate let name: String
    fileprivate(set) var columns: [ColumnDefinition] = [.init(name: "id", type: .serialPrimaryKey, null: false)]
    fileprivate(set) var foreignKeys: [ForeignKeyConstraint] = []

    public mutating func column(_ name: String, type: PostgresDataType, null: Bool = true, default defaultValue: String? = nil) {
        self.columns.append(.init(name: name, type: type, null: null, defaultValue: defaultValue))
    }
    
    public mutating func references(_ tableName: String, null: Bool = false, onDelete: ForeignKeyAction = .cascade, onUpdate: ForeignKeyAction = .noAction) {
        let columnName = "\(tableName)_id"
        self.columns.append(.init(name: columnName, type: .integer, null: null))
        self.foreignKeys.append(.init(
            column: columnName,
            referencesTable: tableName,
            referencesColumn: "id",
            onDelete: onDelete,
            onUpdate: onUpdate
        ))
    }
}

public enum SchemaAction {
    case createTable(TableDefinition)
    case dropTable(TableDefinition)
    case addColumn(ColumnDefinition, to: String)
    case dropColumn(ColumnDefinition, from: String)
    case addIndex(IndexDefinition)
    case dropIndex(IndexDefinition)

    public func upSql() -> String {
        switch self {
        case .createTable(let definition):
            let columnSQLs = definition.columns.map { $0.sqlRepresentation }
            let foreignKeySQLs = definition.foreignKeys.map { $0.sqlRepresentation }
            let allDefinitions = (columnSQLs + foreignKeySQLs).joined(separator: ", ")
            return "CREATE TABLE IF NOT EXISTS \"\(definition.name)\" (\(allDefinitions))"
        case .dropTable(let definition):
            return "DROP TABLE IF EXISTS \"\(definition.name)\""
        case .addColumn(let definition, let tableName):
            return "ALTER TABLE IF EXISTS \"\(tableName)\" ADD COLUMN \(definition.sqlRepresentation)"
        case .dropColumn(let definition, let tableName):
            return "ALTER TABLE IF EXISTS \"\(tableName)\" DROP COLUMN \"\(definition.name)\""
        case .addIndex(let definition):
            let uniqueSQL = definition.isUnique ? "UNIQUE " : ""
            let columnsSQL = definition.columns.map { "\"\($0)\"" }.joined(separator: ", ")
            return "CREATE \(uniqueSQL)INDEX \"\(definition.name)\" ON \"\(definition.tableName)\" (\(columnsSQL))"
        case .dropIndex(let definition):
            return "DROP INDEX IF EXISTS \"\(definition.name)\""
        }
    }

    public func downSql() -> String {
        switch self {
        case .createTable(let definition):
            return "DROP TABLE IF EXISTS \"\(definition.name)\""
        case .dropTable(let definition):
            let columnSQLs = definition.columns.map { $0.sqlRepresentation }
            let foreignKeySQLs = definition.foreignKeys.map { $0.sqlRepresentation }
            let allDefinitions = (columnSQLs + foreignKeySQLs).joined(separator: ", ")
            return "CREATE TABLE IF NOT EXISTS \"\(definition.name)\" (\(allDefinitions))"
        case .addColumn(let definition, let tableName):
            return "ALTER TABLE IF EXISTS \"\(tableName)\" DROP COLUMN \"\(definition.name)\""
        case .dropColumn(let definition, let tableName):
            return "ALTER TABLE IF EXISTS \"\(tableName)\" ADD COLUMN \(definition.sqlRepresentation)"
        case .addIndex(let definition):
            return "DROP INDEX IF EXISTS \"\(definition.name)\""
        case .dropIndex(let definition):
            let uniqueSQL = definition.isUnique ? "UNIQUE " : ""
            let columnsSQL = definition.columns.map { "\"\($0)\"" }.joined(separator: ", ")
            return "CREATE \(uniqueSQL)INDEX \"\(definition.name)\" ON \"\(definition.tableName)\" (\(columnsSQL))"
        }
    }
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

    public func addColumn(_ name: String, type: PostgresDataType, null: Bool = true, default defaultValue: String? = nil, table: String) {
        let column = ColumnDefinition(name: name, type: type, null: null, defaultValue: defaultValue)
        self.actions.append(.addColumn(column, to: table))
    }

    public func dropColumn(_ name: String, type: PostgresDataType, null: Bool = true, default defaultValue: String? = nil, from table: String) {
        let column = ColumnDefinition(name: name, type: type, null: null, defaultValue: defaultValue)
        self.actions.append(.dropColumn(column, from: table))
    }

    public func addIndex(on table: String, columns: [String], isUnique: Bool = false, name: String? = nil) {
        let definition = IndexDefinition(tableName: table, columns: columns, isUnique: isUnique, name: name)
        self.actions.append(.addIndex(definition))
    }

    public func dropIndex(on table: String, columns: [String], isUnique: Bool = false, name: String? = nil) {
        let definition = IndexDefinition(tableName: table, columns: columns, isUnique: isUnique, name: name)
        self.actions.append(.dropIndex(definition))
    }
}


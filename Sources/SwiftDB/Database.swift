//
//  Database.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/21/25.
//
import PostgresNIO

public final class Database: Sendable {
    private let client: PostgresClient
    private let connectionTask: Task<Void, Never>

    private init(client: PostgresClient, connectionTask: Task<Void, Never>) {
        self.client = client
        self.connectionTask = connectionTask
    }

    public static func connect(config: DatabaseConfig, eventLoopGroup: EventLoopGroup) async throws -> Database {
        let postgresConfig = PostgresClient.Configuration(
            host: config.host,
            port: config.port,
            username: config.username,
            password: config.password,
            database: config.database,
            tls: .disable 
        )

        let client = PostgresClient(configuration: postgresConfig, eventLoopGroup: eventLoopGroup)

        let connectionTask = Task {
            await client.run()
        }

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask { try await client.query("SELECT 1") }

                group.addTask {
                    try await Task.sleep(until: .now + .seconds(5))
                    throw ConnectionError.timeout
                }

                defer { group.cancelAll() }

                return try await group.next()!
            }
        } catch {
            throw DatabaseError.connectionFailed(underlying: error)
        }

        return Database(client: client, connectionTask: connectionTask)
    }

    public func query(_ query: PostgresQuery) async throws -> PostgresRowSequence {
        do { return try await client.query(query) } catch {
            throw DatabaseError.queryFailed(query: query.description, underlying: error)
        }
    }

    public func shutdown() {
        connectionTask.cancel()
    }

    public static func create(name: String, maintenanceConfig: DatabaseConfig, eventLoopGroup: EventLoopGroup) async throws -> Database {
        guard isSafeDatabaseName(name) else {
            throw DatabaseError.invalidDatabaseName(name: name)
        }
        
        let maintenanceDatabase = try await connect(config: maintenanceConfig, eventLoopGroup: eventLoopGroup)
        defer { maintenanceDatabase.shutdown() }
        
        let query = PostgresQuery(stringLiteral: "CREATE DATABASE \"\(name)\"")
        do { _ = try await maintenanceDatabase.query(query) } catch DatabaseError.queryFailed(_, let error) where (error as? PSQLError)?.serverInfo?[.sqlState] == "42P04" {
            throw DatabaseError.databaseAlreadyExists(name: name, underlying: error)
        }

        var config = maintenanceConfig
        config.database = name

        return try await connect(config: config, eventLoopGroup: eventLoopGroup)
    }

    public static func drop(name: String, maintenanceConfig: DatabaseConfig, eventLoopGroup: EventLoopGroup) async throws {
        guard isSafeDatabaseName(name) else {
            throw DatabaseError.invalidDatabaseName(name: name)
        }

        let maintenanceDatabase = try await connect(config: maintenanceConfig, eventLoopGroup: eventLoopGroup)
        defer { maintenanceDatabase.shutdown() }
        let query = PostgresQuery(stringLiteral: "DROP DATABASE IF EXISTS \"\(name)\"")
        _ = try await maintenanceDatabase.query(query)
    }

    public static func reset(name: String, maintenanceConfig: DatabaseConfig, eventLoopGroup: EventLoopGroup) async throws -> Database {
        guard isSafeDatabaseName(name) else {
            throw DatabaseError.invalidDatabaseName(name: name)
        }

        try await drop(name: name, maintenanceConfig: maintenanceConfig, eventLoopGroup: eventLoopGroup)
        return try await create(name: name, maintenanceConfig: maintenanceConfig, eventLoopGroup: eventLoopGroup)
    }

    private static func isSafeDatabaseName(_ name: String) -> Bool {
        guard let first = name.first, first.isLetter || first == "_" else {
            return false
        }
        return name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }
 
}

public enum ConnectionError: Error {
    case timeout
}

public enum DatabaseError: Error {
    case connectionFailed(underlying: Error)
    case queryFailed(query: String, underlying: Error)
    case unexpected(underlying: Error)
    case invalidDatabaseName(name: String)
    case databaseAlreadyExists(name: String, underlying: Error)
}

public struct DatabaseConfig {
    public var host: String
    public var port: Int
    public var username: String
    public var password: String? 
    public var database: String
    public var tls: Bool

    public init(
        host: String = "localhost", 
        port: Int = 5432, 
        username: String, 
        password: String? = nil, 
        database: String,
        tls: Bool = false
    ) {
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.database = database
        self.tls = tls
    }
}
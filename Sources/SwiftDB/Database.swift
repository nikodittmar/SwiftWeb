//
//  Database.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/21/25.
//
import PostgresNIO

/// The main entry point for interacting with a PostgreSQL database.
///
/// This class provides a high-level API for connecting to a database, executing queries,
/// running transactions, and performing administrative tasks like creating or dropping databases.
/// It integrates connection pooling, structured logging, and automatic handling of transactions.
public final class Database: Sendable {
    private let client: PostgresClient
    private let connectionTask: Task<Void, Never>
    public let logger: Logger

    private init(client: PostgresClient, connectionTask: Task<Void, Never>, logger: Logger) {
        self.client = client
        self.connectionTask = connectionTask
        self.logger = logger
    }

    /// Establishes a connection to the database and performs a health check.
    ///
    /// - Parameters:
    ///   - config: The `DatabaseConfig` containing connection details.
    ///   - eventLoopGroup: The `EventLoopGroup` to use for the connection.
    ///   - logger: A `Logger` instance for logging database operations.
    /// - Throws: `DatabaseError.connectionFailed` if the health check fails or the connection cannot be established.
    /// - Returns: A connected and ready-to-use `Database` instance.
    public static func connect(config: DatabaseConfig, eventLoopGroup: EventLoopGroup, logger: Logger = Logger(label: "SwiftDB")) async throws -> Database {
        logger.debug("Connecting to database.")
        let postgresConfig = PostgresClient.Configuration(
            host: config.host,
            port: config.port,
            username: config.username,
            password: config.password,
            database: config.database,
            tls: config.tls
        )

        let client = PostgresClient(configuration: postgresConfig, eventLoopGroup: eventLoopGroup, backgroundLogger: logger)

        let connectionTask = Task {
            await client.run()
        }

        // Database health check
        let timeout = config.connectionTimeout

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask { try await client.query("SELECT 1") }

                group.addTask {
                    try await Task.sleep(until: .now + timeout)
                    throw ConnectionError.timeout
                }

                defer { group.cancelAll() }

                return try await group.next()!
            }
        } catch {
            logger.critical("Database health check failed!")
            throw DatabaseError.connectionFailed(underlying: error)
        }

        return Database(client: client, connectionTask: connectionTask, logger: logger)
    }

    /// Executes a SQL query against the database.
    ///
    /// - Parameter query: The `PostgresQuery` to execute. This can be created with safe string interpolation.
    /// - Throws: `DatabaseError.queryFailed` if the database server returns an error.
    /// - Returns: A `PostgresRowSequence` that can be used to iterate over the resulting rows.
    public func query(_ query: PostgresQuery) async throws -> PostgresRowSequence {
        logger.trace("Running database query", metadata: ["query": .string(query.description)])
        do { return try await client.query(query) } catch {
            logger.error("Database query failed", metadata: [
                "query": .string(query.description),
                "error": .string(String(describing: error))
            ])
            throw DatabaseError.queryFailed(query: query.description, underlying: error)
        }
    }

    /// Executes a closure within a database transaction.
    ///
    /// The transaction is automatically committed if the closure returns successfully,
    /// or rolled back if the closure throws an error.
    ///
    /// - Parameter closure: A closure that receives a `PostgresConnection` to be used for all queries within the transaction.
    /// - Throws: Any error thrown by the closure or a connection error.
    /// - Returns: The value returned by the closure.
    public func withTransaction<T>(_ closure: (PostgresConnection) async throws -> T) async throws -> T {
        return try await client.withTransaction(logger: logger) { connection in
            return try await closure(connection)
        }
    }

    /// Shuts down the database connection pool gracefully.
    public func shutdown() {
        logger.debug("Shutting down database...")
        connectionTask.cancel()
    }

    /// Creates a new database on the server.
    ///
    /// - Parameters:
    ///   - name: The name for the new database. Must conform to safe identifier rules.
    ///   - maintenanceConfig: The configuration for connecting to a maintenance database (e.g., "postgres").
    ///   - eventLoopGroup: The `EventLoopGroup` for the connection.
    ///   - logger: A `Logger` for logging operations.
    /// - Throws: `DatabaseError` if the name is invalid, the database already exists, or the creation fails.
    /// - Returns: A new `Database` instance connected to the newly created database.
    public static func create(name: String, maintenanceConfig: DatabaseConfig, eventLoopGroup: EventLoopGroup, logger: Logger = Logger(label: "SwiftDB")) async throws -> Database {
        logger.debug("Creating database...")
        guard isSafeDatabaseName(name) else {
            throw DatabaseError.invalidDatabaseName(name: name)
        }
        
        let maintenanceDatabase = try await connect(config: maintenanceConfig, eventLoopGroup: eventLoopGroup, logger: logger)
        defer { maintenanceDatabase.shutdown() }
        
        let query = PostgresQuery(stringLiteral: "CREATE DATABASE \"\(name)\"")
        do { _ = try await maintenanceDatabase.query(query) } catch DatabaseError.queryFailed(_, let error) where (error as? PSQLError)?.serverInfo?[.sqlState] == "42P04" {
            throw DatabaseError.databaseAlreadyExists(name: name, underlying: error)
        } catch {
            throw DatabaseError.unexpected(underlying: error)
        }

        var config = maintenanceConfig
        config.database = name

        return try await connect(config: config, eventLoopGroup: eventLoopGroup, logger: logger)
    }

    /// Drops a database from the server.
    ///
    /// This function uses `DROP DATABASE IF EXISTS` and will not fail if the database doesn't exist.
    ///
    /// - Parameters:
    ///   - name: The name of the database to drop.
    ///   - maintenanceConfig: The configuration for connecting to a maintenance database (e.g., "postgres").
    ///   - eventLoopGroup: The `EventLoopGroup` for the connection.
    ///   - logger: A `Logger` for logging operations.
    /// - Throws: `DatabaseError` if the name is invalid or the operation fails for an unexpected reason.
    public static func drop(name: String, maintenanceConfig: DatabaseConfig, eventLoopGroup: EventLoopGroup, logger: Logger = Logger(label: "SwiftDB")) async throws {
        logger.debug("Dropping database...")
        guard isSafeDatabaseName(name) else {
            throw DatabaseError.invalidDatabaseName(name: name)
        }

        let maintenanceDatabase = try await connect(config: maintenanceConfig, eventLoopGroup: eventLoopGroup, logger: logger)
        defer { maintenanceDatabase.shutdown() }

        let query = PostgresQuery(stringLiteral: "DROP DATABASE IF EXISTS \"\(name)\"")
        
        do { _ = try await maintenanceDatabase.query(query) } catch {
            throw DatabaseError.unexpected(underlying: error)
        }
    }

    /// Drops a database if it exists and then creates it again.
    ///
    /// - Parameters:
    ///   - name: The name of the database to reset.
    ///   - maintenanceConfig: The configuration for connecting to a maintenance database (e.g., "postgres").
    ///   - eventLoopGroup: The `EventLoopGroup` for the connection.
    ///   - logger: A `Logger` for logging operations.
    /// - Throws: `DatabaseError` if the name is invalid or the operation fails.
    /// - Returns: A new `Database` instance connected to the reset database.
    public static func reset(name: String, maintenanceConfig: DatabaseConfig, eventLoopGroup: EventLoopGroup, logger: Logger = Logger(label: "SwiftDB")) async throws -> Database {
        logger.debug("Resetting database...")
        guard isSafeDatabaseName(name) else {
            throw DatabaseError.invalidDatabaseName(name: name)
        }
        try await drop(name: name, maintenanceConfig: maintenanceConfig, eventLoopGroup: eventLoopGroup, logger: logger)
        return try await create(name: name, maintenanceConfig: maintenanceConfig, eventLoopGroup: eventLoopGroup, logger: logger)
    }

    private static func isSafeDatabaseName(_ name: String) -> Bool {
        guard !name.isEmpty, let first = name.first else { return false }

        guard first.isLetter || first == "_" else {
            return false
        }

        return name.dropFirst().allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "$" }
    }
 
}

/// An error that can occur during a connection attempt.
public enum ConnectionError: Error {
    /// The connection attempt timed out.
    case timeout
}

/// An error related to database operations.
public enum DatabaseError: Error {
    /// A failure to connect to the database server. Contains the underlying error.
    case connectionFailed(underlying: Error)
    /// A query failed to execute. Contains the failed query string and the underlying server error.
    case queryFailed(query: String, underlying: Error)
    /// An unexpected error occurred.
    case unexpected(underlying: Error)
    /// The provided database name is invalid.
    case invalidDatabaseName(name: String)
    /// The database that was being created already exists.
    case databaseAlreadyExists(name: String, underlying: Error)
    /// A required migration was not found.
    case missingMigration(name: String)
    /// Roll back the database with a step less than one.
    case invalidRollbackStep
}

/// Configuration details for connecting to a PostgreSQL database.
public struct DatabaseConfig: Sendable {
    /// The hostname or IP address of the database server.
    public var host: String
    /// The port number of the database server.
    public var port: Int
    /// The username for authentication.
    public var username: String
    /// The password for authentication.
    public var password: String? 
    /// The name of the database to connect to.
    public var database: String
    /// The TLS configuration for the connection.
    public var tls: PostgresClient.Configuration.TLS
    /// The duration to wait before a connection attempt is considered timed out.
    public var connectionTimeout: Duration

    public init(
        host: String = "localhost", 
        port: Int = 5432, 
        username: String, 
        password: String? = nil, 
        database: String,
        tls: PostgresClient.Configuration.TLS = .disable,
        connectionTimeout: Duration = .seconds(5)
    ) {
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.database = database
        self.tls = tls
        self.connectionTimeout = connectionTimeout
    }
}
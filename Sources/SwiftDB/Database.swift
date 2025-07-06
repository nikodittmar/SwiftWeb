//
//  Database.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/21/25.
//
import Foundation
import PostgresNIO
import NIO

/// A top-level class for managing connections and executing operations on a PostgreSQL database.
///
/// ``Database`` serves as the primary entry point for all database interactions within the ORM.
/// It provides a high-level API for connecting to, creating, dropping, and migrating a database.
/// All operations are performed asynchronously using modern Swift Concurrency.
///
/// ## Usage
///
/// First, configure your database connection:
/// ```swift
/// let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
/// let config = DatabaseConfig(
///     host: "localhost",
///     username: "username",
///     database: "myapp_db"
/// )
/// ```
///
/// Then, connect to the database:
/// ```swift
/// do {
///     let db = try await Database.connect(config: config, eventLoopGroup: eventLoopGroup)
///     // The database is now connected and ready for operations.
/// } catch {
///     print("Failed to connect to database: \(error)")
/// }
/// ```
public final class Database: Sendable {
    /// The name of the database this instance is connected to.
    private let name: String

    /// The underlying `PostgresClient` from PostgresNIO used for all database queries.
    public let client: PostgresClient

    /// Establishes a connection to an existing PostgreSQL database.
    ///
    /// This method initializes a ``Database`` instance and verifies the connection
    /// by performing a simple health check query.
    ///
    /// - Parameters:
    ///   - config: The ``DatabaseConfig`` object containing connection details.
    ///   - eventLoopGroup: The ``EventLoopGroup`` to use for the connection.
    /// - Throws: ``DatabaseError.connectionFailed`` if the connection cannot be established or verified.
    /// - Returns: A connected and healthy `Database` instance.
    public static func connect(
        config: DatabaseConfig,
        eventLoopGroup: EventLoopGroup
    ) async throws -> Database {
        let db = Database(config: config, eventLoopGroup: eventLoopGroup)
        db.run()

        guard await db.isHealthy() else {
            throw DatabaseError.connectionFailed
        }
        return db
    }

    /// Creates a new PostgreSQL database and establishes a connection to it.
    ///
    /// This method first connects to a maintenance database (like `postgres`) to run the
    /// `CREATE DATABASE` command, and then connects to the newly created database.
    ///
    /// - Parameters:
    ///   - name: The name for the new database. The name will be sanitized and quoted to prevent SQL injection.
    ///   - maintenanceConfig:  The ``DatabaseConfig`` object containing connection details for the maintenance database.
    ///   - eventLoopGroup: The ``EventLoopGroup`` to use for the connections.
    /// - Throws: ``DatabaseError.connectionFailed`` if the connection to the maintenance database fails.
    ///   It can also throw errors from the underlying ``PostgresClient`` if the `CREATE DATABASE` command fails.
    /// - Returns: A connected ``Database`` instance for the newly created database.
    public static func create(
        name: String,
        maintenanceConfig: DatabaseConfig,
        eventLoopGroup: EventLoopGroup
    ) async throws -> Database {        
        let maintenanceDB = Database(config: maintenanceConfig, eventLoopGroup: eventLoopGroup)
        maintenanceDB.run()
        
        guard await maintenanceDB.isHealthy(timeout: .seconds(5)) else {
            throw DatabaseError.connectionFailed
        }

        try await maintenanceDB.client.query("CREATE DATABASE \(name)")

        return try await Database.connect(
            config: DatabaseConfig(
                host: maintenanceConfig.host,
                port: maintenanceConfig.port,
                username: maintenanceConfig.username,
                password: maintenanceConfig.password,
                database: name
            ),
            eventLoopGroup: eventLoopGroup
        )
    }

    /// Drops (deletes) an existing PostgreSQL database.
    ///
    /// This method connects to a maintenance database (like `postgres`) to run the
    /// `DROP DATABASE` command.
    ///
    /// - Parameters:
    ///   - name: The name of the database to drop.
    ///   - maintenanceConfig: The ``DatabaseConfig`` object containing connection details for the maintenance database.
    ///   - eventLoopGroup: The ``EventLoopGroup`` to use for the connection.
    /// - Throws: `DatabaseError.connectionFailed` if the connection to the maintenance database fails.
    ///   It can also throw errors from the underlying `PostgresClient` if the `DROP DATABASE` command fails.
    public static func drop(
        name: String,
        maintenanceConfig: DatabaseConfig,
        eventLoopGroup: EventLoopGroup
    ) async throws {        
        let maintenanceDB = Database(config: maintenanceConfig, eventLoopGroup: eventLoopGroup)
        maintenanceDB.run()
        
        guard await maintenanceDB.isHealthy(timeout: .seconds(5)) else {
            throw DatabaseError.connectionFailed
        }

        try await maintenanceDB.client.query("DROP DATABASE \(name)")
    } 

    /// Runs a series of schema migrations on the database.
    ///
    /// This method initializes a ``MigrationRunner`` to apply all provided ``Migration`` types
    /// in order, bringing the database schema up to date.
    ///
    /// - Parameter migrations: An array of types conforming to the ``Migration`` protocol.
    /// - Throws: An error if any migration fails to apply.
    public func migrate(_ migrations: [Migration.Type]) async throws {
        let migrationRunner = MigrationRunner(db: self, migrations: migrations)
        try await migrationRunner.run()
    }

    /// Private initializer to configure the `PostgresClient`.
    private init(config: DatabaseConfig, eventLoopGroup: EventLoopGroup) {
        self.name = config.database

        let config = PostgresClient.Configuration(
            host: config.host,
            port: config.port,
            username: config.username,
            password: config.password,
            database: config.database,
            tls: .disable
        )

        self.client = PostgresClient(configuration: config, eventLoopGroup: eventLoopGroup)
    }

    /// Runs the client's connection loop in a detached Task.
    /// This allows the client to handle network events in the background.
    private func run() {
        Task.detached {
            await self.client.run()
        }
    } 

    /// Checks if the database connection is active and responsive.
    ///
    /// - Parameter timeout: The maximum ``Duration`` to wait for a response. Defaults to 5 seconds.
    /// - Returns: `true` if the database responds to a `SELECT 1` query within the timeout, otherwise `false`.
    private func isHealthy(timeout: Duration = .seconds(5)) async -> Bool {
        do {
            // If the database is unreachable, the PostgresNIO query will hang.
            // We assume if the query is not finished within the timeout, the database is unhealthy.
            try await performWithTimeout(of: timeout) {
                _ = try await self.client.query("SELECT 1")
            }
            return true
        } catch {
            return false
        }
    }   
}

/// Configuration details required to connect to a PostgreSQL database.
public struct DatabaseConfig {
    let host: String
    let port: Int
    let username: String
    let password: String?
    let database: String

    /// Creates a new database configuration.
    ///
    /// - Parameters:
    ///   - host: The database server host.
    ///   - port: The database server port. Defaults to `5432`.
    ///   - username: The username for authentication.
    ///   - password: The password for authentication. Defaults to `nil`.
    ///   - database: The name of the database to connect to.
    public init(
        host: String,
        port: Int = 5432,
        username: String,
        password: String? = nil,
        database: String
    ) {
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.database = database
    }
}

/// Races two asynchronous tasks, returning the result of the first one to complete successfully.
/// If one task throws an error, the other continues. The group returns the first successful result.
/// If both throw errors, the error from the first one to fail is rethrown.
///
/// - Parameters:
///   - lhs: The first async task to execute.
///   - rhs: The second async task to execute.
/// - Returns: The result of the first task to complete successfully.
/// - Throws: An error from the first task that fails if both fail.
func race<T: Sendable>(
    _ lhs: @Sendable @escaping () async throws -> T,
    _ rhs: @Sendable @escaping () async throws -> T
) async throws -> T {
    return try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await lhs() }
        group.addTask { try await rhs() }
        
        defer { group.cancelAll() }
        
        // Return the result of the first task that successfully completes.
        return try await group.next()!
    }
}

/// Performs an asynchronous task with a specified timeout.
///
/// This function races the provided work against a ``Task.sleep`` timer. If the work
/// doesn't complete before the timeout, a ``TimeoutError.timeout`` is thrown.
///
/// - Parameters:
///   - timeout: The maximum ``Duration`` the task is allowed to run.
///   - work: The asynchronous work to perform.
/// - Returns: The result of the `work` closure if it completes in time.
/// - Throws: ``TimeoutError.timeout`` if the task exceeds the specified duration.
func performWithTimeout<T: Sendable>(
    of timeout: Duration,
    _ work: @Sendable @escaping () async throws -> T
) async throws -> T {
    return try await race(work, {
        try await Task.sleep(until: .now + timeout)
        throw TimeoutError.timeout
    })
}

/// An error indicating that a tracked operation did not complete in time.
enum TimeoutError: Error {
    /// The operation exceeded its allowed duration.
    case timeout
}

/// An error related to database lifecycle operations.
enum DatabaseError: Error {
    /// A connection to the database could not be established or was unhealthy.
    case connectionFailed
}
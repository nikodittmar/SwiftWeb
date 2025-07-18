//
//  Migration.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/21/25.
//

import PostgresNIO

/// A protocol that defines a single, reversible database migration.
public protocol Migration: Sendable {
    /// A unique name that **must** be prefixed with a timestamp in `YYYYMMDDHHMMSS` format.
    /// This timestamp determines the chronological order in which migrations are executed.
    ///
    /// Example: `"20250718001500_CreateUsersTable"`
    static var name: String { get }

    /// The function that applies the migration's changes to the database.
    /// - Parameter connection: The transactional `PostgresConnection` to use for all queries.
    static func up(on connection: PostgresConnection) async throws

    /// The function that reverts the migration's changes from the database.
    /// - Parameter connection: The transactional `PostgresConnection` to use for all queries.
    static func down(on connection: PostgresConnection) async throws
}

extension Database {

    /// Applies all pending migrations in chronological order.
    ///
    /// This method ensures that migrations are run within a single transaction. If any migration fails,
    /// all previous changes within the batch are automatically rolled back.
    ///
    /// - Parameter migrations: An array of `Migration.Type` to consider for execution.
    /// - Throws: A ``DatabaseError`` or a `PostgresError` if a migration fails.
    public func migrate(_ migrations: [Migration.Type]) async throws {
        logger.debug("Running migrations...")

        let migrations = migrations.sorted { $0.name < $1.name}
        try await createMigrationsTableIfNeeded()

        let completedMigrationNames = Set(try await getCompletedMigrationNames())

        let pendingMigrations = migrations.filter { migration in
            !completedMigrationNames.contains(migration.name)
        }

        try await withTransaction { connection in
            for migration in pendingMigrations {
                print("Running migration: \(migration.name)")
                try await migration.up(on: connection)

                var bindings = PostgresBindings()
                bindings.append(migration.name)
                let query = PostgresQuery(unsafeSQL: "INSERT INTO \"migrations\" (name) VALUES ($1)", binds: bindings)
                _ = try await connection.query(query, logger: logger).get()
            }
        }
        
        if pendingMigrations.isEmpty {
            print("No new migrations to run.")
        }
        logger.debug("Successfully completed \(pendingMigrations.count) migrations.")
    }

    /// Reverts a specified number of the most recent migrations.
    ///
    /// This method ensures that rollbacks are run within a single transaction. If any rollback fails,
    /// all previous changes within the batch are automatically rolled back.
    ///
    /// - Parameters:
    ///   - migrations: An array of all available `Migration.Type` to find the migrations to revert.
    ///   - step: The number of recent migrations to revert. Defaults to 1.
    /// - Throws: A ``DatabaseError`` if a migration definition is missing, the step count is invalid,
    ///   or a `PostgresError` if a `down` method fails.
    public func rollback(_ migrations: [Migration.Type], step: Int = 1) async throws {
        guard step > 0 else {
            throw DatabaseError.invalidRollbackStep
        }

        logger.debug("Rolling back \(step) migrations...")

        let completedMigrationNames = try await getCompletedMigrationNames().sorted(by: >).prefix(step)

        let migrationLookup = Dictionary(uniqueKeysWithValues: migrations.map { ($0.name, $0) })

        let migrationsToRollback = try completedMigrationNames.map { name in
            guard let migration = migrationLookup[name] else {
                throw DatabaseError.missingMigration(name: name)
            }
            return migration
        }

        try await withTransaction { connection in
            for migration in migrationsToRollback {
                print("Rolling back migration: \(migration.name)")
                try await migration.down(on: connection)

                var bindings = PostgresBindings()
                bindings.append(migration.name)
                let query = PostgresQuery(unsafeSQL: "DELETE FROM \"migrations\" WHERE name = ($1)", binds: bindings)
                _ = try await connection.query(query, logger: logger).get()
            }
        }
    }

    private func createMigrationsTableIfNeeded() async throws {
        _ = try await query("""
        CREATE TABLE IF NOT EXISTS "migrations" (
            id SERIAL PRIMARY KEY,
            name TEXT NOT NULL
        )
        """)
    }

    private func getCompletedMigrationNames() async throws -> [String] {
       let rows = try await query("SELECT name FROM \"migrations\"").collect()
        return try rows.map { row in
            try row.decode(String.self)
        }
    }
}


//
//  MigrationRunner.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/21/25.
//
import PostgresNIO

public class MigrationRunner {
    let db: Database
    let migrations: [Migration.Type]
    
    init(db: Database, migrations: [Migration.Type]) {
        self.db = db
        self.migrations = migrations
    }
    
    func run() async throws {
        try await createMigrationsTable()
        let ranMigrations = try await getMigrations()
        let pendingMigrations = migrations.filter { migration in
            !ranMigrations.contains(migration.name)
        }

        for migration in pendingMigrations {
            print("Running migration: \(migration.name)")
            try await migration.up(on: db)
            try await addMigration(name: migration.name)
        }
        
        if pendingMigrations.isEmpty {
            print("No new migrations to run.")
        }
    }
    
    private func createMigrationsTable() async throws {
        let query = """
        CREATE TABLE IF NOT EXISTS "migrations" (
            id SERIAL PRIMARY KEY,
            name TEXT NOT NULL
        )
        """
        try await db.client.query(PostgresQuery(unsafeSQL: query))
    }
    
    private func getMigrations() async throws -> [String] {
        let query = PostgresQuery(unsafeSQL: "SELECT name FROM \"migrations\"")
        let rows = try await db.client.query(query).collect()
        var migrations: [String] = []
        for row in rows {
            let name = try row.decode(String.self)
            migrations.append(name)
        }
        return migrations
    }
    
    private func addMigration(name: String) async throws {
        var bindings = PostgresBindings(capacity: 1)
        bindings.append(name)
        let query = PostgresQuery(unsafeSQL: "INSERT INTO \"migrations\" (name) VALUES ($1)", binds: bindings)
        try await db.client.query(query)
    }
}


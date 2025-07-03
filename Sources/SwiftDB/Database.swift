//
//  Database.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/21/25.
//
import PostgresNIO

public final class Database: Sendable {
    public let client: PostgresClient
    
    public init(config: DatabaseConfig, eventLoopGroup: EventLoopGroup) {
        let config = PostgresClient.Configuration(
            host: config.host,
            port: 5432,
            username: config.username,
            password: config.password,
            database: config.database,
            tls: .disable
        )
        
        self.client = PostgresClient(configuration: config, eventLoopGroup: eventLoopGroup)
    }
    
    public func run() {
        Task.detached {
            await self.client.run()
        }
    }
}

public struct DatabaseConfig {
    let database: String 
    let username: String
    let password: String?
    let host: String

    public init(database: String, username: String, password: String?, host: String) {
        self.database = database
        self.username = username
        self.password = password
        self.host = host
    }
}
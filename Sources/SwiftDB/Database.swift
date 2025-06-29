//
//  Database.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/21/25.
//
import PostgresNIO

public final class Database: Sendable {
    public let client: PostgresClient
    
    public init(eventLoopGroup: EventLoopGroup) {
        let config = PostgresClient.Configuration(
            host: "localhost",
            port: 5432,
            username: "nikodittmar",
            password: nil,
            database: "swiftweb_development",
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


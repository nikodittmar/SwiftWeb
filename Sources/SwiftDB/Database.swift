//
//  Database.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/21/25.
//
import PostgresNIO

final class Database: Sendable {
    let client: PostgresClient
    
    init(eventLoopGroup: EventLoopGroup) {
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
    
    func run() {
        Task.detached {
            await self.client.run()
        }
    }
}


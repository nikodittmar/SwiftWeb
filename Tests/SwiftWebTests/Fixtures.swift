//
//  Fixtures.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/16/25.
//

@testable import SwiftWeb
import NIO
import NIOHTTP1
import Foundation
import PostgresNIO
import SwiftDB
@testable import SwiftView

enum SwiftWebTestFixtures {

    static let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)

    static let testHost = ProcessInfo.processInfo.environment["TEST_DATABASE_HOST"] ?? "localhost"
    static let testPort = Int(ProcessInfo.processInfo.environment["TEST_DATABASE_PORT"] ?? "5432")!
    static let testUsername = ProcessInfo.processInfo.environment["TEST_DATABASE_USERNAME"] ?? "test_username"
    static let testPassword = ProcessInfo.processInfo.environment["TEST_DATABASE_PASSWORD"] ?? "test_password"
    static let testDatabase = ProcessInfo.processInfo.environment["TEST_DATABASE_NAME"] ?? "test_database"

    static let healthyDatabaseConfig = DatabaseConfig(
        host: testHost,
        port: testPort,
        username: testUsername,
        password: testPassword,
        database: testDatabase,
        tls: .disable
    )

    static func database() async throws -> Database {
        return try await Database.connect(config: healthyDatabaseConfig, eventLoopGroup: eventLoopGroup)
    }

    static func request(uri: String, method: HTTPMethod) async throws -> Request {
        Request(head: HTTPRequestHead(version: .http1_1, method: method, uri: uri), body: ByteBuffer(), params: [:], query: [:], app: try await app())
    }

    static func app(router: Router = RouterBuilder().build()) async throws -> Application {
        let router = router
        
        let database = try await database()

        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)

        let viewsDirectory = temporaryDirectory.appendingPathComponent("views", isDirectory: true)
        try FileManager.default.createDirectory(at: viewsDirectory, withIntermediateDirectories: false)

        let publicDirectory = temporaryDirectory.appendingPathComponent("public", isDirectory: true)
        try FileManager.default.createDirectory(at: viewsDirectory, withIntermediateDirectories: false)

        let views = Views(viewsDirectory: viewsDirectory)

        let config = ApplicationConfig(
            router: router, 
            database: database, 
            views: views, 
            eventLoopGroup: eventLoopGroup, 
            publicDirectory: publicDirectory,
            logger: Logger(label: "SwiftWebTests")
        )

        return Application(config: config)
    }
}
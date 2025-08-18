//
//  SwiftWeb.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 7/2/25.
//
import SwiftDB
import ArgumentParser
import Foundation

public protocol SwiftWebConfig {
    static var projectName: String { get }
    static var migrations: [Migration.Type] { get }
    static var port: Int { get }

    static var viewsDirectory: URL { get }
    static var publicDirectory: URL { get }

    static var dotEnvPath: URL { get }
    static var maintenanceDBName: String { get }

    static func configureRoutes(builder: RouterBuilder) -> Router
    static func configureMiddleware() -> [any Middleware]
}

extension SwiftWebConfig {
    public static var dotEnvPath: URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath + "/.env")
    }

    public static var maintenanceDBName: String {
        return "postgres"
    }
}

@available(macOS 15, *)
public struct SwiftWeb<T: SwiftWebConfig>: AsyncParsableCommand {
    public static var configuration: CommandConfiguration {
        CommandConfiguration(
            abstract: "A SwiftWeb Application",
            subcommands: [
                ServerCommand<T>.self,
                RoutesCommand<T>.self,
                DatabaseCommand<T>.self,
                GenerateCommand<T>.self
            ]
        )
    }
    
    public init() {}
}

internal func print(swiftweb message: String) {
    print("\u{1B}[38;5;16;48;5;39m SwiftWeb \u{1B}[0m \(message)")
}



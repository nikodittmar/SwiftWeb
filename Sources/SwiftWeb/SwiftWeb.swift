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
    static func configureRoutes() -> Router
    static var viewsDirectory: URL { get }
    static var dotEnvPath: URL { get }
    static var maintenanceDBName: String { get }
}

extension SwiftWebConfig {
    public static var dotEnvPath: URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath + "/.env")
    }
    public static var maintenanceDBName: String {
        return "postgres"
    }
}

@available(macOS 13, *)
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
    print("\033[38;5;16;48;5;39m SwiftWeb \033[0m \(message)")
}



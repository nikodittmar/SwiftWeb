//
//  CLI.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 7/2/25.
//
import SwiftDB
import ArgumentParser
import Foundation

public protocol ApplicationConfig {
    static var projectName: String { get }
    static var migrations: [Migration.Type] { get }
    static var port: Int { get }
    static func configureRoutes() -> Router
    static var viewsDirectory: URL { get }
    static var dotEnvPath: URL { get }
}

public struct CLI<T: ApplicationConfig>: ParsableCommand {
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



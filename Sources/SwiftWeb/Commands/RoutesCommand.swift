//
//  RoutesCommand.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 7/2/25.
//
import ArgumentParser

struct RoutesCommand<T: ApplicationConfig>: ParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "routes",
            abstract: "Displays all registered routes."
        )
    }
    
    func run() throws {
        let router = T.configureRoutes()
        router.printRoutes()
    }
}

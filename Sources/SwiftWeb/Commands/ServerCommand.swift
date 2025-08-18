//
//  ServerCommand.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 7/2/25.
//
import ArgumentParser
import Foundation
import SwiftView
import SwiftDB
import NIO
import Logging

struct ServerCommand<T: SwiftWebConfig>: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "server",
            abstract: "Starts the web server."
        )
    }
    
    func run() async throws {
        var logger = Logger(label: "SwiftWeb")
        logger.logLevel = .debug
    
        logger.debug("Starting SwiftWeb server.")
        
        do { try loadDotEnv(from: T.dotEnvPath, logger: logger) } catch {
            logger.critical("Error loading .env file: \(error)")
            return
        }

        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        
        let middleware = T.configureMiddleware()  
        let builder = RouterBuilder(globalMiddleware: middleware)      
        let router: Router = T.configureRoutes(builder: builder)
        
        let viewsDirectory = T.viewsDirectory
        
        let views = Views(viewsDirectory: viewsDirectory)
        
        let db = try await Database.connect(
            config: getDatabaseConfig(),
            eventLoopGroup: eventLoopGroup,
            logger: logger
        )

        let applicationConfig = ApplicationConfig(
            router: router, 
            database: db, 
            views: views, 
            eventLoopGroup: eventLoopGroup, 
            publicDirectory: T.publicDirectory, 
            logger: logger
        )
        
        let application = Application(config: applicationConfig)
        
        try application.run(port: T.port)
    }
}


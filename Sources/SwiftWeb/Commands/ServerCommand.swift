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

struct ServerCommand<T: ApplicationConfig>: ParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "server",
            abstract: "Starts the web server."
        )
    }
    
    func run() throws {
        print("[SwiftWeb] 🚀 Starting Server...")
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        
        let router: Router = T.configureRoutes()
        
        let viewsDirectory = T.viewsDirectory
        
        let views = Views(viewsDirectory: viewsDirectory)
        
        let db = try configureDatabase(eventLoopGroup: eventLoopGroup)
        
        db.run()
        
        let application = Application(router: router, db: db, views: views, eventLoopGroup: eventLoopGroup)
        
        try application.run(port: T.port)
    }
}

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
        print("🚀 Starting Server...")
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        
        let router: Router = T.configureRoutes()
        
        guard let viewsDirectory = Bundle.main.url(forResource: "Views", withExtension: nil) else {
            fatalError("Could not find the Views directory. Check your Package.swift resources.")
        }
        
        let views = Views(viewsDirectory: viewsDirectory)
        
        let db = Database(eventLoopGroup: eventLoopGroup)
        
        db.run()
        
        let application = Application(router: router, db: db, views: views, eventLoopGroup: eventLoopGroup)
        
        try application.run(port: T.port)
    }
}

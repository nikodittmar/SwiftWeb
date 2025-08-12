//
//  Application.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/17/25.
//
import NIO
import NIOHTTP1
import SwiftDB
import SwiftView
import Logging
import Foundation

public final class Application: Sendable {
    public let router: Router
    public let db: Database
    public let views: Views
    public let logger: Logger
    public let eventLoopGroup: EventLoopGroup
    public let publicDirectory: URL
    
    public init(config: ApplicationConfig) {
        self.router = config.router
        self.db = config.database
        self.views = config.views
        self.eventLoopGroup = config.eventLoopGroup
        self.logger = config.logger
        self.publicDirectory = config.publicDirectory
    }
    
    public func run(port: Int = 4000) throws {
        defer { 
            do {
                try self.eventLoopGroup.syncShutdownGracefully()
            } catch {
                logger.critical("Failed to sync shutdown gracefully \(error)")
            }
        }
        
        let bootstrap = ServerBootstrap(group: eventLoopGroup)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                
                channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(HTTPHandler(application: self))
                }
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(.maxMessagesPerRead, value: 16)
            .childChannelOption(.recvAllocator, value: AdaptiveRecvByteBufferAllocator())

        do {
            let channel = try bootstrap.bind(host: "0.0.0.0", port: port).wait()
            if let localAddress = channel.localAddress, let host = localAddress.ipAddress, let port = localAddress.port {
                logger.info("Server running on http://\(host):\(port)")
            } else {
                logger.warning("Server running, but could not determine local address")
            }
            try channel.closeFuture.wait()
        } catch {
            logger.critical("Failed to start server: \(error)")
        }
    }
}

public struct ApplicationConfig {
    let router: Router
    let database: Database
    let views: Views
    let eventLoopGroup: EventLoopGroup
    let publicDirectory: URL
    let logger: Logger
}

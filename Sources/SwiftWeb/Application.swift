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

public protocol Responder: Sendable {
    func respond(to requestHead: HTTPRequestHead, body: ByteBuffer?) async -> Response
}

public final class Application: Responder {
    public let router: Router
    public let db: Database
    public let views: Views
    public let eventLoopGroup: EventLoopGroup
    
    public init(router: Router, db: Database, views: Views, eventLoopGroup: EventLoopGroup) {
        self.router = router
        self.db = db
        self.views = views
        self.eventLoopGroup = eventLoopGroup
    }
    
    public func respond(to requestHead: HTTPRequestHead, body: ByteBuffer?) async -> Response {
        if let (handler, params, query) = router.match(uri: requestHead.uri, method: requestHead.method) {
            let request: Request = Request(head: requestHead, body: body, params: params, query: query, app: self)
            let response = try? await handler(request)
            return response ?? .html("<h1>ERROR!!</h1>")
        } else {
            return Response(status: .notFound)
        }
    }
    
    public func run(port: Int = 4000) throws {
        defer { try! self.eventLoopGroup.syncShutdownGracefully() }
        
        let bootstrap = ServerBootstrap(group: eventLoopGroup)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                
                channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(HTTPHandler(responder: self))
                }
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(.maxMessagesPerRead, value: 16)
            .childChannelOption(.recvAllocator, value: AdaptiveRecvByteBufferAllocator())

        let channel = try! bootstrap.bind(host: "127.0.0.1", port: port).wait()
        print("Server running on \(channel.localAddress!)")

        try! channel.closeFuture.wait()
    }
}

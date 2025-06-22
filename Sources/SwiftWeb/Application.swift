//
//  Application.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/17/25.
//
import NIO
import NIOHTTP1

public protocol Responder: Sendable {
    func respond(to requestHead: HTTPRequestHead, body: ByteBuffer?) async -> Response
}

public final class Application: Responder {
    let router: Router
    
    init(router: Router) {
        self.router = router
    }
    
    public func respond(to requestHead: HTTPRequestHead, body: ByteBuffer?) async -> Response {
        if let (handler, params, query) = router.match(uri: requestHead.uri, method: requestHead.method) {
            let request: Request = Request(head: requestHead, body: body, params: params, query: query)
            return await handler(request)
        } else {
            return Response(status: .notFound)
        }
    }
    
    public func run(port: Int = 4000) throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

        defer { try! group.syncShutdownGracefully() }
        
        let bootstrap = ServerBootstrap(group: group)
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

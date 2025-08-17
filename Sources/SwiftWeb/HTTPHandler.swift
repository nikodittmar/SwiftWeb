//
//  HTTPHandler.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/17/25.
//
import NIO
import NIOHTTP1
import Logging
import SwiftWebCore

public final class HTTPHandler: ChannelInboundHandler, @unchecked Sendable {
    public typealias InboundIn = HTTPServerRequestPart
    public typealias OutboundOut = HTTPServerResponsePart
    
    private enum State {
        case idle, waitingForRequestBody, sendingResponse
        mutating func requestReceived() {
            precondition(self == .idle, "Invalid state for request received: \(self)")
            self = .waitingForRequestBody
        }
        mutating func requestComplete() {
            precondition(self == .waitingForRequestBody, "Invalid state for request complete: \(self)")
            self = .sendingResponse
        }
        mutating func responseComplete() {
            precondition(self == .sendingResponse, "Invalid state for response complete: \(self)")
            self = .idle
        }
    }
    
    private var body: ByteBuffer?
    private var state: State = .idle
    private var requestHead: HTTPRequestHead?
    
    private let application: Application

    private var matchedRoute: MatchedRoute? = nil 

    public init(application: Application) {
        self.application = application
    }
    
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let reqPart = self.unwrapInboundIn(data)
        
        switch reqPart {
        case .head(let head):
            self.requestHead = head
            self.state.requestReceived()
            self.matchedRoute = self.application.router.match(head: head)
        case .body(var buffer):
            if self.body == nil {
                self.body = buffer
            } else {
                self.body!.writeBuffer(&buffer)
            }
        case .end:
            guard self.state == .waitingForRequestBody else {
                return
            }

            self.state.requestComplete()

            guard let matchedRoute = self.matchedRoute else {
                self.handleError(SwiftWebError(type: .internalServerError, reason: "HTTPHandler failed to match route before request end"), context: context, version: .http1_1)
                return
            }

            let promise = context.eventLoop.makePromise(of: Response.self)

            promise.completeWithTask {
                return await matchedRoute.execute(body: self.body, app: self.application)
            }

            promise.futureResult.whenSuccess { response in
                self.respond(with: response, context: context)
            }          
        }
    }

    private func handleError(_ error: Error, context: ChannelHandlerContext, version: HTTPVersion) {
        self.respond(with: .error(error, on: application, version: version), context: context)
    }

    private func respond(with response: Response, context: ChannelHandlerContext) {
        let head = HTTPResponseHead(version: response.version, status: response.status, headers: response.headers)

        context.write(self.wrapOutboundOut(.head(head)), promise: nil)

        if let body = response.body {
            context.write(self.wrapOutboundOut(.body(.byteBuffer(body))), promise: nil)
        }

        context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)

        self.state.responseComplete()

        self.body = nil
        self.requestHead = nil
        self.matchedRoute = nil
    }
}

extension ChannelHandlerContext: @unchecked @retroactive Sendable {}

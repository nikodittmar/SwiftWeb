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

            #if SWIFTWEB_LOGGING_ENABLED
            application.logger.info("Started \(head.method.rawValue) \(head.uri)")
            #endif

            self.requestHead = head
            self.state.requestReceived()

            do {
                self.matchedRoute = try self.application.router.match(uri: head.uri, method: head.method)
            } catch {
                self.state.requestComplete()
                self.handleError(error, context: context, version: head.version)
            }

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

            let application = self.application

            guard let requestHead = self.requestHead, let matchedRoute = self.matchedRoute else {
                self.handleError(SwiftWebError(type: .internalServerError, reason: "HTTPHandler failed to process request head or match route before request end"), context: context, version: .http1_1)
                return
            }

            let promise = context.eventLoop.makePromise(of: Response.self)

            let request: Request = Request(head: requestHead, body: self.body, params: matchedRoute.pathParameters, query: matchedRoute.queryParameters, app: application)

            promise.completeWithTask {
                return try await matchedRoute.handler(request)
            }

            promise.futureResult.whenSuccess { response in
                self.respond(with: response, context: context, version: requestHead.version)
            }

            promise.futureResult.whenFailure { error in
                self.handleError(error, context: context, version: requestHead.version)
            }            
        }
    }

    private func handleError(_ error: Error, context: ChannelHandlerContext, version: HTTPVersion) {
        #if SWIFTWEB_LOGGING_ENABLED
        if let swiftWebError = error as? SwiftWebError {
            application.logger.error("Completed with error \(swiftWebError.type.status.code) \(swiftWebError.type.status.reasonPhrase) reason: \(swiftWebError.reason)")
        } else {
            application.logger.error("Completed with unknown error \(error.localizedDescription)")
        }
        #endif

        self.respond(with: .error(error, on: application), context: context, version: version)
    }

    private func respond(with response: Response, context: ChannelHandlerContext, version: HTTPVersion) {
        #if SWIFTWEB_LOGGING_ENABLED
        if let requestHead = self.requestHead {
            application.logger.info("Completed \(response.status.code) \(response.status.reasonPhrase) for \(requestHead.method.rawValue) \(requestHead.uri)")
        } else {
            application.logger.warning("Completed \(response.status.code) \(response.status.reasonPhrase) for an unknown URI and method")
        }
        #endif

        let head = HTTPResponseHead(version: version, status: response.status, headers: response.headers)

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

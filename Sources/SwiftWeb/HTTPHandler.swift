//
//  HTTPHandler.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/17/25.
//
import NIO
import NIOHTTP1

public final class HTTPHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart
    
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
    private var keepAlive: Bool = false
    private var state: State = .idle
    private var requestHead: HTTPRequestHead?
    
    private let responder: Responder
    
    init(responder: Responder) {
        self.responder = responder
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let reqPart = self.unwrapInboundIn(data)
        
        switch reqPart {
        case .head(let head):
            self.keepAlive = head.isKeepAlive
            self.requestHead = head
            self.state.requestReceived()
        case .body(var buffer):
            if self.body == nil {
                self.body = buffer
            } else {
                self.body!.writeBuffer(&buffer)
            }
        case .end:
            self.state.requestComplete()
            if let request = self.requestHead {
                let responder = self.responder
                let body = self.body
                let promise = context.eventLoop.makePromise(of: Response.self)
                promise.completeWithTask {
                    return await responder.respond(to: request, body: body)
                }
                promise.futureResult.whenSuccess { response in
                    let head = HTTPResponseHead(version: request.version, status: response.status, headers: response.headers)
                    context.write(self.wrapOutboundOut(.head(head)), promise: nil)
                    if let body = response.body {
                        context.write(self.wrapOutboundOut(.body(.byteBuffer(body))), promise: nil)
                    }
                    context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
                    self.state.responseComplete()
                }
            }
            
        }
    }
    
}

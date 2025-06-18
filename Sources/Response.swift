//
//  Response.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/16/25.
//
import Foundation
import NIO
import NIOHTTP1

public struct Response: Sendable {
    public var status: HTTPResponseStatus
    public var headers: HTTPHeaders
    public var body: ByteBuffer?

    public init(status: HTTPResponseStatus, headers: HTTPHeaders = HTTPHeaders(), body: ByteBuffer? = nil) {
        self.status = status
        self.headers = headers
        self.body = body
    }
    
    public static func json(_ json: String, status: HTTPResponseStatus = .ok) -> Response {
        var headers: HTTPHeaders = HTTPHeaders()
        headers.add(name: "content-type", value: "application/json")
        var buffer = ByteBufferAllocator().buffer(capacity: json.utf8.count)
        buffer.writeString(json)
        return Response(status: status, headers: headers, body: buffer)
    }
}

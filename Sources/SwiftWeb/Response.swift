//
//  Response.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/16/25.
//
import Foundation
import NIO
import NIOHTTP1
import SwiftDB
import SwiftView

public struct Response: Sendable {
    public var status: HTTPResponseStatus
    public var headers: HTTPHeaders
    public var body: ByteBuffer?

    static let dateProvider: HeaderDateProvider = HeaderDateProvider()

    public init(status: HTTPResponseStatus, headers: HTTPHeaders = HTTPHeaders(), body: ByteBuffer? = nil) {
        self.status = status
        self.headers = headers
        self.body = body
    }
    
    public static func view<T: Encodable>(_ name: String, layout: Layout? = Layout(name: "Layouts/application"), with context: T, on request: Request, status: HTTPResponseStatus = .ok) throws -> Response {
        return .html(try request.app.views.render(name, with: context, layout: layout), status: status)
    }

    public static func view<T: Collection & Encodable>(_ name: String, layout: Layout? = Layout(name: "Layouts/application"), collection: T, key: String, on request: Request, status: HTTPResponseStatus = .ok) throws -> Response where T.Element: Encodable {
        let context = [ key: collection ]
        return try .view(name, layout: layout, with: context, on: request, status: status)
    }

    public static func view<T: Collection & Encodable>(_ name: String, layout: Layout? = Layout(name: "Layouts/application"), models: T, key: String? = nil, on request: Request, status: HTTPResponseStatus = .ok) throws -> Response where T.Element: Model {
        let collectionKey = key ?? T.Element.schema
        return try .view(name, layout: layout, collection: models, key: collectionKey, on: request, status: status)
    }

    public static func view(_ name: String, layout: Layout? = Layout(name: "Layouts/application"), on request: Request, status: HTTPResponseStatus = .ok) throws -> Response {
        return .html(try request.app.views.render(name, layout: layout), status: status)
    }
    
    public static func json<T: Encodable>(_ encodable: T, status: HTTPResponseStatus = .ok) throws -> Response {
        let data = try JSONEncoder().encode(encodable)
        let buffer = ByteBufferAllocator().buffer(data: data)
        var headers = headers()
        headers.add(name: "content-type", value: "application/json; charset=utf-8")
        headers.add(name: "content-length", value: String(buffer.readableBytes))

        return Response(status: status, headers: headers, body: buffer)
    }
    
    public static func html(_ html: String, status: HTTPResponseStatus = .ok) -> Response {
        var buffer = ByteBufferAllocator().buffer(capacity: html.utf8.count)
        buffer.writeString(html)
        
        var headers = headers()
        headers.add(name: "content-type", value: "text/html; charset=utf-8")
        headers.add(name: "content-length", value: String(buffer.readableBytes))
        
        return Response(status: status, headers: headers, body: buffer)
    }
    
    public static func redirect(to location: String) -> Response {
        var headers = headers()
        headers.add(name: "location", value: location)
        return Response(status: .seeOther, headers: headers)
    }
    
    public static func headers() -> HTTPHeaders {
        var headers = HTTPHeaders()
        
        headers.add(name: "date", value: dateProvider.get())
        
        headers.add(name: "cache-control", value: "no-cache, no-store, must-revalidate")

        return headers
    }
}

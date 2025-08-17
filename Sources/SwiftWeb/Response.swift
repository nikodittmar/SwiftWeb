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
import SwiftWebCore

public struct Response: Sendable {
    public static let applicationLayout = Layout(name: "Layouts/application")

    public var version: HTTPVersion
    public var status: HTTPResponseStatus
    public var headers: HTTPHeaders
    public var body: ByteBuffer?

    static let dateProvider: HeaderDateProvider = HeaderDateProvider()

    public init(status: HTTPResponseStatus, headers: HTTPHeaders = HTTPHeaders(), body: ByteBuffer? = nil, version: HTTPVersion = .http1_1) {
        self.status = status
        self.headers = headers
        self.body = body
        self.version = version
    }

    public static func error(_ error: Error, name: String = "error", on app: Application, version: HTTPVersion = .http1_1) -> Response {
        if let swiftWebError = error as? SwiftWebError, let errorHTML = try? app.views.render(name, with: swiftWebError.context)  {
            return .html(errorHTML, status: swiftWebError.type.status, version: version)
        } else {
            return .html("<h1>An unexpected error occurred</h1><p>Additionally, the error view could not be rendered.</p>", status: .internalServerError, version: version)
        }
    }
    
    public static func view<T: Encodable>(_ name: String, layout: Layout? = applicationLayout, with context: T, on request: Request, status: HTTPResponseStatus = .ok, version: HTTPVersion = .http1_1) throws -> Response {
        return .html(try request.app.views.render(name, with: context, layout: layout), status: status, version: version)
    }

    public static func view<T: Collection & Encodable>(_ name: String, layout: Layout? = applicationLayout, collection: T, key: String, on request: Request, status: HTTPResponseStatus = .ok, version: HTTPVersion = .http1_1) throws -> Response where T.Element: Encodable {
        let context = [ key: collection ]
        return try .view(name, layout: layout, with: context, on: request, status: status, version: version)
    }

    public static func view<T: Collection & Encodable>(_ name: String, layout: Layout? = applicationLayout, models: T, key: String? = nil, on request: Request, status: HTTPResponseStatus = .ok, version: HTTPVersion = .http1_1) throws -> Response where T.Element: Model {
        let collectionKey = key ?? T.Element.schema
        return try .view(name, layout: layout, collection: models, key: collectionKey, on: request, status: status, version: version)
    }

    public static func view(_ name: String, layout: Layout? = applicationLayout, on request: Request, status: HTTPResponseStatus = .ok) throws -> Response {
        return .html(try request.app.views.render(name, layout: layout), status: status, version: request.head.version)
    }
    
    public static func json<T: Encodable>(_ encodable: T, status: HTTPResponseStatus = .ok, version: HTTPVersion = .http1_1) throws -> Response {
        let data = try JSONEncoder().encode(encodable)
        let buffer = ByteBufferAllocator().buffer(data: data)
        var headers = headers()
        headers.add(name: "content-type", value: "application/json; charset=utf-8")
        headers.add(name: "content-length", value: String(buffer.readableBytes))

        return Response(status: status, headers: headers, body: buffer, version: version)
    }
    
    public static func html(_ html: String, status: HTTPResponseStatus = .ok, version: HTTPVersion = .http1_1) -> Response {
        var buffer = ByteBufferAllocator().buffer(capacity: html.utf8.count)
        buffer.writeString(html)
        
        var headers = headers()
        headers.add(name: "content-type", value: "text/html; charset=utf-8")
        headers.add(name: "content-length", value: String(buffer.readableBytes))
        
        return Response(status: status, headers: headers, body: buffer, version: version)
    }
    
    public static func redirect(to location: String, version: HTTPVersion = .http1_1) -> Response {
        var headers = HTTPHeaders()
        headers.add(name: "date", value: dateProvider.get())
        headers.add(name: "location", value: location)
        return Response(status: .seeOther, headers: headers, version: version)
    }
    
    public static func headers() -> HTTPHeaders {
        var headers = HTTPHeaders()
        
        headers.add(name: "date", value: dateProvider.get())
        
        headers.add(name: "cache-control", value: "no-cache, no-store, must-revalidate")

        return headers
    }

    public func withCookie(_ cookie: Cookie) -> Response {
        withHeader(name: "Set-Cookie", value: cookie.serialized())
    }

    public func withHeader(name: String, value: String) -> Response {
        var newResponse = self
        newResponse.headers.add(name: name, value: value)
        return newResponse
    }

    public func withCookies(_ cookies: [Cookie]) -> Response {
        var newResponse = self
        for cookie in cookies {
            newResponse.headers.add(name: "Set-Cookie", value: cookie.serialized())
        }
        return newResponse
    }
}

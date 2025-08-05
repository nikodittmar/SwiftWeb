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
    
    public static func view<T: Encodable>(_ name: String, with context: T, on request: Request, status: HTTPResponseStatus = .ok) -> Response {
        
        do {
            return .html(try request.app.views.render(name, with: context), status: status)
        } catch {
            return .html("<div>\(error)</div>")
        }
    }
    
    public static func json(_ json: String, status: HTTPResponseStatus = .ok) -> Response {
        var buffer = ByteBufferAllocator().buffer(capacity: json.utf8.count)
        buffer.writeString(json)
        
        var headers = headers()
        headers.add(name: "content-type", value: "application/json; charset=utf-8")
        headers.add(name: "content-length", value: String(buffer.readableBytes))
        
        return Response(status: status, headers: headers, body: buffer)
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
        let date = Date.now.formatted(
            Date.VerbatimFormatStyle(
                format: """
                \(weekday: .abbreviated), \
                \(day: .twoDigits) \
                \(month: .abbreviated) \ 
                \(year: .defaultDigits) \
                \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits):\(second: .twoDigits) \
                \(timeZone: .specificName(.short))
                """,
                locale: Locale(identifier: "en_US_POSIX"),
                timeZone: .gmt,
                calendar: Calendar(identifier: .gregorian)
            )
        )
        headers.add(name: "date", value: date)
        headers.add(name: "cache-control", value: "no-cache, no-store, must-revalidate")

        return headers
    }
}

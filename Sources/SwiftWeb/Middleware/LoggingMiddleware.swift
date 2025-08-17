//
//  LoggingMiddleware.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 8/15/25.
//

public struct LoggingMiddleware: Middleware {
    public func handle(req: Request, next: @Sendable (Request) async throws -> Response) async throws -> Response {
        return try await next(req)
    }
}
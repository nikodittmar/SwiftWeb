//
//  Middleware.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 8/15/25.
//

public protocol Middleware: Sendable {
    func handle(req: Request, next: @Sendable (Request) async throws -> Response) async throws -> Response
}
//
//  Controller.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/16/25.
//
import NIOHTTP1

public protocol ResourcefulController: Controller {
    init()
    @Sendable func index(req: Request) async throws -> Response
    @Sendable func show(req: Request) async throws -> Response
    @Sendable func new(req: Request) async throws -> Response
    @Sendable func create(req: Request) async throws -> Response
    @Sendable func edit(req: Request) async throws -> Response
    @Sendable func update(req: Request) async throws -> Response
    @Sendable func destroy(req: Request) async throws -> Response
}

public protocol Controller: Sendable {}

public extension Controller {
    private var resourceName: String {
        let typeName = String(describing: type(of: self))
        let withoutSuffix = typeName.hasSuffix("Controller") ? String(typeName.dropLast(10)) : typeName
        return withoutSuffix.lowercased()
    }
    
    func view<T: Encodable>(
        _ name: String,
        with context: T,
        on request: Request,
        status: HTTPResponseStatus = .ok
    ) throws -> Response {
        let viewName = name.contains("/") ? name : "\(self.resourceName)/\(name)"
        return try .view(viewName, with: context, on: request, status: status)
    }
}

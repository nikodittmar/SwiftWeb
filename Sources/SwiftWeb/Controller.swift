//
//  Controller.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/16/25.
//
import NIOHTTP1

public protocol Controller: Sendable {
    init()
    @Sendable func index(req: Request) -> Response
    @Sendable func show(req: Request) -> Response
    @Sendable func new(req: Request) -> Response
    @Sendable func create(req: Request) -> Response
    @Sendable func edit(req: Request) -> Response
    @Sendable func update(req: Request) -> Response
    @Sendable func destroy(req: Request) -> Response
}

public extension Controller {
    @Sendable func index(req: Request) -> Response {
        return Response(status: .notImplemented)
    }
    @Sendable func show(req: Request) -> Response {
        return Response(status: .notImplemented)
    }
    @Sendable func new(req: Request) -> Response {
        return Response(status: .notImplemented)
    }
    @Sendable func create(req: Request) -> Response {
        return Response(status: .notImplemented)
    }
    @Sendable func edit(req: Request) -> Response {
        return Response(status: .notImplemented)
    }
    @Sendable func update(req: Request) -> Response {
        return Response(status: .notImplemented)
    }
    @Sendable func destroy(req: Request) -> Response {
        return Response(status: .notImplemented)
    }
    
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

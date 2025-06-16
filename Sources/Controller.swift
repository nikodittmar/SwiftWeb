//
//  Controller.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/16/25.
//

public protocol Controller {
    init()
    func index(req: Request) -> Response
    func show(req: Request) -> Response
    func new(req: Request) -> Response
    func create(req: Request) -> Response
    func edit(req: Request) -> Response
    func update(req: Request) -> Response
    func destroy(req: Request) -> Response
}

public extension Controller {
    func index(req: Request) -> Response {
        return Response(status: .notImplemented)
    }
    func show(req: Request) -> Response {
        return Response(status: .notImplemented)
    }
    func new(req: Request) -> Response {
        return Response(status: .notImplemented)
    }
    func create(req: Request) -> Response {
        return Response(status: .notImplemented)
    }
    func edit(req: Request) -> Response {
        return Response(status: .notImplemented)
    }
    func update(req: Request) -> Response {
        return Response(status: .notImplemented)
    }
    func destroy(req: Request) -> Response {
        return Response(status: .notImplemented)
    }
}

//
//  Response.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/16/25.
//
import NIOHTTP1

public struct Response {
    public let status: HTTPResponseStatus
    
    static func notFound() -> Response {
        return Response(status: .notFound)
    }
}

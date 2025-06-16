//
//  Request.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/16/25.
//
import NIOHTTP1

public struct Request {
    public let method: HTTPMethod
    public let headers: HTTPHeaders
    public let path: String
    public var params: [String: String] = [:]
}

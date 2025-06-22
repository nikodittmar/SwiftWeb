//
//  Request.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/16/25.
//
import NIO
import NIOHTTP1

public struct Request {
    public let method: HTTPMethod
    public let headers: HTTPHeaders
    public let body: ByteBuffer?
    public let path: String
    public let params: [String: String]
    public let query: [String: String]
    
    public init(head: HTTPRequestHead, body: ByteBuffer?, params: [String: String], query: [String: String]) {
        self.method = head.method
        self.headers = head.headers
        self.body = body
        self.path = head.uri
        self.params = params
        self.query = query
    }
}

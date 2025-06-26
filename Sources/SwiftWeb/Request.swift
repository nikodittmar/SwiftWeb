//
//  Request.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/16/25.
//
import NIO
import NIOHTTP1
import SwiftDB
import Foundation

public struct Request: Sendable {
    public let head: HTTPRequestHead
    
    public var headers: HTTPHeaders {
        return head.headers
    }
    
    public let body: ByteBuffer?
    public let path: String
    public let params: [String: String]
    public let query: [String: String]
    public let db: Database
    
    public init(head: HTTPRequestHead, body: ByteBuffer?, params: [String: String], query: [String: String], db: Database) {
        self.head = head
        self.body = body
        self.path = head.uri
        self.params = params
        self.query = query
        self.db = db
    }
    
    public func decode<T: Decodable>(_ type: T.Type) throws -> T {
        if let body = self.body {
            return try JSONDecoder().decode(T.self, from: body)
        } else {
            throw RequestError.noBody
        }
    }
}

enum RequestError: Error {
    case noBody
}

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
    
    public func decode<T : Decodable>(as type: T.Type) throws -> T {
        guard let contentType = self.headers["content-type"].first else {
            throw RequestError.missingContentType
        }
        
        guard let decoder = RequestDecoder.decoder(for: contentType) else {
            throw RequestError.unsupportedContentType
        }
        
        guard let body = self.body else {
            throw RequestError.noBody
        }
        
        return try decoder.decode(T.self, from: Data(buffer: body))
    }
}

public enum RequestError: Error {
    case missingContentType
    case unsupportedContentType
    case noBody
}

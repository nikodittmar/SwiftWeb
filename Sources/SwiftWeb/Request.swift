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
    public let app: Application
    
    public init(head: HTTPRequestHead, body: ByteBuffer?, params: [String: String], query: [String: String], app: Application) {
        self.head = head
        self.body = body
        self.path = head.uri
        self.params = params
        self.query = query
        self.app = app
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

    public func get<T: LosslessStringConvertible>(param: String, as type: T.Type = T.self) throws -> T {
        guard let stringValue = self.params[param] else {
            throw RequestError.missingParameter
        }

        guard let value = T(stringValue) else {
            throw RequestError.parameterTypeMismatch
        }

        return value
    }

    public func get<T: Decodable>(_ model: T.Type = T.self, encoding: Encoding) throws -> T {
        guard let body = body else {
            throw RequestError.noBody
        }

        let data = Data(buffer: body)

        switch encoding {
            case .json:
                return try JSONDecoder().decode(T.self, from: data)
            case .form:
                return try URLQueryDecoder().decode(T.self, from: data)
        }
    }   
}

public enum Encoding {
    case form
    case json
}

public enum RequestError: Error {
    case missingContentType
    case unsupportedContentType
    case noBody
    case missingParameter
    case parameterTypeMismatch
    case decodingError
}

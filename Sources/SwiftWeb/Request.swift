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
import SwiftWebCore

public struct Request: Sendable {
    public let head: HTTPRequestHead
    
    public var headers: HTTPHeaders {
        return head.headers
    }
    
    public let body: ByteBuffer?
    public let path: String
    public let params: [String: String]
    public let query: [String: String]
    public lazy var cookies: [String: String] = {
        return Self.parseCookies(from: self.headers)
    }()

    public let app: Application
    
    public init(head: HTTPRequestHead, body: ByteBuffer?, params: [String: String], query: [String: String], app: Application) {
        self.head = head
        self.body = body
        self.path = head.uri
        self.params = params
        self.query = query
        self.app = app
    }

    public func get<T: LosslessStringConvertible>(param: String, as type: T.Type = T.self) throws -> T {
        guard let stringValue = self.params[param] else {
            throw SwiftWebError(type: .internalServerError, reason: "Route parameter '\(param)' not found. This indicates a server-side configuration error.")
        }

        guard let value = T(stringValue) else {
            throw SwiftWebError(type: .badRequest, reason: "Route parameter '\(param)' with value '\(stringValue)' could not be converted to type '\(T.self)'.")
        }

        return value
    }

    public func get<T: Decodable>(_ decodable: T.Type = T.self, encoding: Encoding) throws -> T {
        guard let body = body else {
            throw SwiftWebError(type: .badRequest, reason: "Request body is empty, cannot decode '\(T.self)'.")
        }

        let data = Data(buffer: body)

        do {
            switch encoding {
                case .json:
                    return try JSONDecoder().decode(T.self, from: data)
                case .form:
                    return try URLQueryDecoder().decode(T.self, from: data)
            }
        } catch let error as DecodingError {
            throw SwiftWebError(type: .badRequest, reason: "Failed to decode request body as '\(T.self)'. Error: \(error.localizedDescription)")
        } catch {
            throw SwiftWebError(type: .internalServerError, reason: "An unexpected error occurred during body decoding. Error: \(error.localizedDescription)")
        }
    }

    private static func parseCookies(from headers: HTTPHeaders) -> [String: String] {
        var cookies: [String: String] = [:]
        if let cookieHeader = headers["cookie"].first {
            let pairs = cookieHeader.split(separator: ";")
            for pair in pairs {
                let parts = pair.split(separator: "=", maxSplits: 1)
                if parts.count == 2 {
                    let key = String(parts[0].trimmingCharacters(in: .whitespaces))
                    let value = String(parts[1].trimmingCharacters(in: .whitespaces))
                    cookies[key] = value
                }
            }
        }
        return cookies
    }

}

public enum Encoding {
    case form
    case json
}

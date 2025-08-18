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
    public var context: [String: Sendable]

    public let app: Application
    
    public init(head: HTTPRequestHead, body: ByteBuffer?, params: [String: String], query: [String: String], app: Application, context: [String: Sendable] = [:]) {
        self.head = head
        self.body = body
        self.path = head.uri
        self.params = params
        self.query = query
        self.app = app
        self.context = context
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

    public func get<T: LosslessStringConvertible>(query: String, as type: T.Type = T.self) throws -> T {
        guard let stringValue = self.query[query] else {
            throw SwiftWebError(type: .internalServerError, reason: "Query parameter '\(query)' not found. This indicates a server-side configuration error.")
        }

        guard let value = T(stringValue) else {
            throw SwiftWebError(type: .badRequest, reason: "Query parameter '\(query)' with value '\(stringValue)' could not be converted to type '\(T.self)'.")
        }

        return value
    }

    public func get<T: Sendable>(context: String, as type: T.Type = T.self) throws -> T {
        guard let value = self.context[context] else {
            throw SwiftWebError(type: .internalServerError, reason: "Context object '\(context)' not found. This indicates a server-side configuration error.")
        }

        guard let value = value as? T else {
            throw SwiftWebError(type: .badRequest, reason: "Context object '\(context)' with value '\(value)' could not be converted to type '\(T.self)'.")
        }

        return value
    }

    mutating public func get<T: Sendable>(cookie: String, as type: T.Type = T.self) throws -> T {
        guard let value = self.cookies[cookie] else {
            throw SwiftWebError(type: .internalServerError, reason: "Cookie '\(cookie)' not found. This indicates a server-side configuration error.")
        }

        guard let value = value as? T else {
            throw SwiftWebError(type: .badRequest, reason: "Cookie '\(cookie)' with value '\(value)' could not be converted to type '\(T.self)'.")
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

    public mutating func setSession(_ key: String, to value: String?) {
        let session = try! get(context: "session", as: Session.self)
        session.set(key, to: value)
    }

    public func getSession(_ key: String) -> String? {
        let session = try! get(context: "session", as: Session.self)
        return session.get(key)
    }

}

public enum Encoding {
    case form
    case json
}

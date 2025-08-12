//
//  Controller.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/16/25.
//

import Foundation

public struct Cookie: Sendable {
    public var name: String
    public var value: String
    public var expires: Date?
    public var maxAge: Int?
    public var domain: String?
    public var path: String? = "/"
    public var isSecure: Bool = false
    public var isHTTPOnly: Bool = false
    public var sameSite: SameSitePolicy = .lax

    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }

    public enum SameSitePolicy: String, Sendable {
        case strict = "Strict"
        case lax = "Lax"
        case none = "None"
    }

    internal func serialized() -> String {
        var parts: [String] = ["\(name)=\(value)"]

        if let domain = domain { parts.append("Domain=\(domain)") }
        if let path = path { parts.append("Path=\(path)") }
        if let maxAge = maxAge { parts.append("Max-Age=\(maxAge)") }

        if let expires = expires {
            parts.append("Expires=\(expires.formatted(DateFormat.RFC1123))")
        }

        if isSecure { parts.append("Secure") }
        if isHTTPOnly { parts.append("HttpOnly") }
        parts.append("SameSite=\(sameSite.rawValue)")

        return parts.joined(separator: "; ")
    }
}
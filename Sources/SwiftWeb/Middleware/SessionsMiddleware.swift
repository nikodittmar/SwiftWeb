//
//  SessionsMiddleware.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 8/15/25.
//

import Synchronization
import SwiftWebCore
import Foundation

public final class Session: Sendable {
    public let id: String = UUID().uuidString
    private let mutex: Mutex<(data: [String: String], isDirty: Bool)> = Mutex((data: [:], isDirty: false))

    public func set(_ key: String, to value: String?) {
        mutex.withLock { state in
            state.isDirty = true
            state.data[key] = value
        }
    }

    public func get(_ key: String) -> String? {
        return mutex.withLock { state in
            return state.data[key]
        }
    }

    public var isDirty: Bool {
        return mutex.withLock { state in
            return state.isDirty
        }
    }

    public func resetDirty() {
        mutex.withLock { state in
            state.isDirty = false
        }
    }
}

public struct SessionsMiddleware: Middleware {
    static let store = InMemoryCache<String, Session>()
    static let cookieName = "swiftweb_session_id"

    public init() {}

    public func handle(req: Request, next: @Sendable (Request) async throws -> Response) async throws -> Response {
        var req = req

        if let session_id: String = try? req.get(cookie: Self.cookieName), let session = try? await Self.store.get(session_id) {
            session.resetDirty()
            req.context["session"] = session
        } else {
            req.context["session"] = Session()
        }

        let session = req.context["session"] as! Session

        var res = try await next(req)

        if session.isDirty {
            try? await Self.store.set(session.id, to: session)
            let cookie = Cookie(name: Self.cookieName, value: session.id)
            res = res.withCookie(cookie)
        }

        return res
    }    
}
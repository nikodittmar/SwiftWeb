//
//  SessionsMiddlewareTests.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/16/25.
//

import Testing
import SwiftWeb
import NIOHTTP1

@Suite(.serialized) struct SessionsMiddlewareTests {

    func router() -> Router {
        let builder = RouterBuilder(globalMiddleware: [SessionsMiddleware()])
        
        builder.get("/set") { req in
            var req = req 
            req.setSession("id", to: "67")
            return Response(status: .ok)
        }

        builder.get("/empty") { req in Response(status: .ok)}

        builder.get("/read") { req in
            let id = req.getSession("id")
            if let id = id {
                return Response(status: .ok).withHeader(name: "id", value: id)
            } else {
                return Response(status: .notFound)
            }
        }

        builder.get("/update") { req in
            var req = req 
            req.setSession("id", to: "99")
            return Response(status: .ok)
        }

        return builder.build()
    }

    @Test func test_SessionsMiddlware_NewSessionSetsCookie_IsValid() async throws {
        let router = router()
        let match = router.match(head: HTTPRequestHead(version: .http1_1, method: .GET, uri: "/set"))
        let res = await match.execute(body: nil, app: try await SwiftWebTestFixtures.app())
        #expect(res.headers["Set-Cookie"] != [])
    }

    @Test func test_SessionsMiddlware_ExistingSessionDoesNotSetCookie_IsValid() async throws {
        let app = try await SwiftWebTestFixtures.app()
        let router = router()
        let matchSet = router.match(head: HTTPRequestHead(version: .http1_1, method: .GET, uri: "/set"))
        let resSet = await matchSet.execute(body: nil, app: app)
        let setCookieHeader = try #require(resSet.headers["Set-Cookie"].first)
        let cookiePair = String(setCookieHeader.split(separator: ";")[0])
        var headers = HTTPHeaders()
        headers.add(name: "Cookie", value: cookiePair)
        let matchRead = router.match(head: HTTPRequestHead(version: .http1_1, method: .GET, uri: "/read", headers: headers))
        let resRead = await matchRead.execute(body: nil, app: app)
        #expect(resRead.headers["Set-Cookie"] == [])
        #expect(resRead.headers["id"] == ["67"])
    }

    @Test func test_SessionsMiddlware_SessionNotSetDoesNotSetCookie_IsValid() async throws {
        let router = router()
        let match = router.match(head: HTTPRequestHead(version: .http1_1, method: .GET, uri: "/empty"))
        let res = await match.execute(body: nil, app: try await SwiftWebTestFixtures.app())
        #expect(res.headers["Set-Cookie"] == [])
    }

    @Test func test_SessionsMiddlware_NoSessionID_IsValid() async throws {
        let app = try await SwiftWebTestFixtures.app()
        let router = router()
        let match = router.match(head: HTTPRequestHead(version: .http1_1, method: .GET, uri: "/read"))
        let res = await match.execute(body: nil, app: app)
        #expect(res.status == .notFound)
    }

    @Test func test_SessionsMiddleware_UpdatingSession_SetsCookie() async throws {
        let app = try await SwiftWebTestFixtures.app()
        let router = router()

        let matchSet = router.match(head: HTTPRequestHead(version: .http1_1, method: .GET, uri: "/set"))
        let resSet = await matchSet.execute(body: nil, app: app)
        let setCookieHeader = try #require(resSet.headers["Set-Cookie"].first)
        let cookiePair = String(setCookieHeader.split(separator: ";")[0])

        var headers = HTTPHeaders()
        headers.add(name: "Cookie", value: cookiePair)
        let matchUpdate = router.match(head: HTTPRequestHead(version: .http1_1, method: .GET, uri: "/update", headers: headers))
        let resUpdate = await matchUpdate.execute(body: nil, app: app)

        #expect(resUpdate.headers["Set-Cookie"] != [])

        let matchRead = router.match(head: HTTPRequestHead(version: .http1_1, method: .GET, uri: "/read", headers: headers))
        let resRead = await matchRead.execute(body: nil, app: app)
        #expect(resRead.headers["id"] == ["99"])
    }

    @Test func test_SessionsMiddleware_InvalidSessionID_IsHandledGracefully() async throws {
        let app = try await SwiftWebTestFixtures.app()
        let router = router()
        
        var headers = HTTPHeaders()
        headers.add(name: "Cookie", value: "swiftweb_session_id=FAKE-ID-12345")

        let matchRead = router.match(head: HTTPRequestHead(version: .http1_1, method: .GET, uri: "/read", headers: headers))
        let resRead = await matchRead.execute(body: nil, app: app)

        #expect(resRead.status == .notFound)
        #expect(resRead.headers["Set-Cookie"] == [])
    }
}
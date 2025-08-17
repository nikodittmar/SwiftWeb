//
//  RouterTests.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/16/25.
//

import Testing
@testable import SwiftWeb
import SwiftWebCore
import NIO
import NIOHTTP1

struct TestController: ResourcefulController {
    func index(req: Request) async throws -> Response { return Response(status: .ok) }
    func show(req: Request) async throws -> Response { return Response(status: .ok) }
    func new(req: Request) async throws -> Response { return Response(status: .ok) }
    func create(req: Request) async throws -> Response { return Response(status: .ok) }
    func edit(req: Request) async throws -> Response { return Response(status: .ok) }
    func update(req: Request) async throws -> Response { return Response(status: .ok) }
    func destroy(req: Request) async throws -> Response { return Response(status: .ok) }
}

@Suite struct dRouterTests {
    struct DummyMiddleware: Middleware {
        func handle(req: Request, next: @Sendable (Request) async throws -> Response) async throws -> Response {
            return Response(status: .ok).withHeader(name: "X-Dummy-Middleware-Used", value: "true")
        }
    }

    struct SecondDummyMiddleware: Middleware {
        func handle(req: Request, next: @Sendable (Request) async throws -> Response) async throws -> Response {
            return Response(status: .ok).withHeader(name: "X-Second-Dummy-Middleware-Used", value: "true")
        }
    }

    let builder = RouterBuilder()
    
    let emptyHandler: Handler = { _ in Response(status: .ok) }
    
    @Test func test_Router_GetRoute_IsValid() throws {
        builder.get("/users", to: emptyHandler)
        let router = builder.build()
        let _ = router.match(head: HTTPRequestHead(version: .http1_1, method: .GET, uri: "/users"))
    }
    
    @Test func test_Router_ExtraRouteComponent_ThrowsError() {
        builder.get("/users", to: emptyHandler)
        let router = builder.build()
        #expect(throws: SwiftWebError.self) {
            let _ = try router.match(uri: "/users/info", method: .GET)
        }
    }
    
    @Test func test_Router_MissingRouteComponent_ThrowsError() {
        builder.get("/users/:id/comments", to: emptyHandler)
        let router = builder.build()
        #expect(throws: SwiftWebError.self) {
            let _ = try router.match(uri: "/users", method: .GET)
        }
    }
    
    @Test func test_Router_IncorrectMethod_ThrowsError() {
        builder.get("/users", to: emptyHandler)
        let router = builder.build()
        #expect(throws: SwiftWebError.self) {
            let _ = try router.match(uri: "/users", method: .POST)
        }
    }
    
    @Test func test_Router_PostRoute_IsValid() throws {
        builder.post("/users", to: emptyHandler)
        let router = builder.build()
        let _ = try router.match(uri: "/users", method: .POST)
    }
    
    @Test func test_Router_PatchRoute_IsValid() throws {
        builder.patch("/users/:id", to: emptyHandler)
        let router = builder.build()
        let _ = try router.match(uri: "/users/12", method: .PATCH)
    }
    
    @Test func test_Router_PutRoute_IsValid() throws {
        builder.put("/users/:id", to: emptyHandler)
        let router = builder.build()
        let _ = try router.match(uri: "/users/45", method: .PUT)
    }
    
    @Test func test_Router_DeleteRoute_IsValid() throws {
        builder.delete("/users/:id", to: emptyHandler)
        let router = builder.build()
        let _ = try router.match(uri: "/users/2", method: .DELETE)
    }
    
    @Test func test_Router_ParameterRoute_IsValid() throws {
        builder.patch("/posts/:id", to: emptyHandler)
        let router = builder.build()
        let match = try router.match(uri: "/posts/123", method: .PATCH)
        #expect(match.pathParameters["id"] == "123")
    }
    
    @Test func test_Router_NestedParameterRoute_IsValid() throws {
        builder.patch("/posts/:post_id/comments/:comment_id", to: emptyHandler)
        let router = builder.build()
        let match = try router.match(uri: "/posts/578/comments/127", method: .PATCH)
        #expect(match.pathParameters["post_id"] == "578")
        #expect(match.pathParameters["comment_id"] == "127")
    }
    
    @Test func test_Router_QueryParameters_IsValid() throws {
        builder.get("/users", to: emptyHandler)
        let router = builder.build()
        let match = try router.match(uri: "/users?name=John&age=30", method: .GET)
        #expect(match.queryParameters["name"] == "John")
        #expect(match.queryParameters["age"] == "30")
    }
    
    @Test func test_Router_Resources_IsValid() throws {
        builder.resources("/users", for: TestController.self, parameter: "user_id")
        let router = builder.build()
        let _ = try router.match(uri: "/users", method: .GET)
        let show = try router.match(uri: "/users/12", method: .GET)
        let _ = try router.match(uri: "/users/new", method: .GET)
        let _ = try router.match(uri: "/users", method: .POST)
        let edit = try router.match(uri: "/users/888/edit", method: .GET)
        let update_patch = try router.match(uri: "/users/78", method: .PATCH)
        let update_put = try router.match(uri: "/users/21", method: .PUT)
        let delete = try router.match(uri: "/users/44", method: .DELETE)
        #expect(show.pathParameters["user_id"] == "12")
        #expect(edit.pathParameters["user_id"] == "888")
        #expect(update_patch.pathParameters["user_id"] == "78")
        #expect(update_put.pathParameters["user_id"] == "21")
        #expect(delete.pathParameters["user_id"] == "44")
    }
    
    @Test func test_Router_NestedResources_IsValid() throws {
        builder.resources("/users", for: TestController.self) { router in
            router.resources("/posts", for: TestController.self, parameter: "post_id")
        }
        let router = builder.build()
        let index = try router.match(uri: "/users/14/posts", method: .GET)
        let show = try router.match(uri: "/users/78/posts/12", method: .GET)
        let new = try router.match(uri: "/users/8992/posts/new", method: .GET)
        let create = try router.match(uri: "/users/22/posts", method: .POST)
        let edit = try router.match(uri: "/users/828/posts/134/edit", method: .GET)
        let update_patch = try router.match(uri: "/users/32/posts/98", method: .PATCH)
        let update_put = try router.match(uri: "/users/21/posts/78", method: .PUT)
        let delete = try router.match(uri: "/users/09/posts/167", method: .DELETE)
        #expect(index.pathParameters["id"] == "14")
        #expect(show.pathParameters["id"] == "78")
        #expect(show.pathParameters["post_id"] == "12")
        #expect(new.pathParameters["id"] == "8992")
        #expect(create.pathParameters["id"] == "22")
        #expect(edit.pathParameters["id"] == "828")
        #expect(edit.pathParameters["post_id"] == "134")
        #expect(update_patch.pathParameters["id"] == "32")
        #expect(update_patch.pathParameters["post_id"] == "98")
        #expect(update_put.pathParameters["id"] == "21")
        #expect(update_put.pathParameters["post_id"] == "78")
        #expect(delete.pathParameters["id"] == "09")
        #expect(delete.pathParameters["post_id"] == "167")
    }
    
    @Test func test_Router_Namespace_IsValid() throws {
        builder.namespace("/api") { router in
            router.get("/hello", to: emptyHandler)
        }
        let router = builder.build()
        let _ = try router.match(uri: "/api/hello", method: .GET)
    }

    @Test func test_Router_NestedNamespace_IsValid() throws {
        builder.namespace("/api") { router in
            router.namespace("/v1") { RouterBuilder in
                router.get("/hello", to: emptyHandler)
            }
            router.get("/documentation", to: emptyHandler)
        }
        let router = builder.build()
        let _ = try router.match(uri: "/api/documentation", method: .GET)
        let _ = try router.match(uri: "/api/v1/hello", method: .GET)
    }
    
    @Test func test_Router_RoutePrecendence_IsValid() throws {
        builder.get("/users/:id", to: emptyHandler)
        builder.get("/users/new", to: emptyHandler)
        let router = builder.build()
        let dynamicRoute = try router.match(uri: "/users/12", method: .GET)
        let staticRoute = try router.match(uri: "/users/new", method: .GET)
        #expect(dynamicRoute.pathParameters["id"] == "12")
        #expect(staticRoute.pathParameters["id"] == nil)
    }

    @Test func test_Router_GlobalMiddleware_IsValid() async throws {
        let builder = RouterBuilder(globalMiddleware: [DummyMiddleware()])
        builder.get("/hello", to: emptyHandler)
        let router = builder.build()
        let matched = try router.match(uri: "/hello", method: .GET)
        let req = try await SwiftWebTestFixtures.request(uri: "/hello", method: .GET)
        
    }

    @Test func test_Router_LocalMiddleware_IsValid() throws {
        builder.use(DummyMiddleware())

    }
}

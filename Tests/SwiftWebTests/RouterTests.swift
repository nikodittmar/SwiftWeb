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

@Suite(.serialized) struct RouterTests {
    struct DummyMiddleware: Middleware {
        func handle(req: Request, next: @Sendable (Request) async throws -> Response) async throws -> Response {
            var res = try await next(req)
            res.headers.add(name: "X-Dummy-Middleware-Used", value: "true")
            return res
        }
    }

    struct SecondDummyMiddleware: Middleware {
        func handle(req: Request, next: @Sendable (Request) async throws -> Response) async throws -> Response {
            var res = try await next(req)
            res.headers.add(name: "X-Second-Dummy-Middleware-Used", value: "true")
            return res
        }
    }

    let emptyHandler: Handler = { _ in Response(status: .ok) }

    func paramsEchoHandler(params: String...) -> Handler {
        return { req in
            var response = Response(status: .ok)
            for param in params {
                response = response.withHeader(name: param, value: try req.get(param: param))
            }
            return response
        }
    }

    func queryEchoHandler(queries: String...) -> Handler {
        return { req in
            var response = Response(status: .ok)
            for query in queries {
                response = response.withHeader(name: query, value: try req.get(query: query))
            }
            return response
        }
    }
    
    @Test func test_Router_GetRoute_IsValid() async throws {
        let builder = RouterBuilder()
        builder.get("/users", to: emptyHandler)
        let router = builder.build()
        let match = router.match(head: HTTPRequestHead(version: .http1_1, method: .GET, uri: "/users"))
        let app = try await SwiftWebTestFixtures.app()
        let res = await match.execute(body: nil, app: app)
        #expect(res.status == .ok)
    }
    
    @Test func test_Router_ExtraRouteComponent_ReturnsNotFound() async throws {
        let builder = RouterBuilder()
        builder.get("/users", to: emptyHandler)
        let router = builder.build()
        let match = router.match(head: HTTPRequestHead(version: .http1_1, method: .GET, uri: "/users/profile"))
        let app = try await SwiftWebTestFixtures.app()
        let res = await match.execute(body: nil, app: app)
        #expect(res.status == .notFound)
    }
    
    @Test func test_Router_MissingRouteComponent_ReturnsNotFound() async throws {
        let builder = RouterBuilder()
        builder.get("/users/:id/comments", to: emptyHandler)
        let router = builder.build()
        let match = router.match(head: HTTPRequestHead(version: .http1_1, method: .GET, uri: "/users"))
        let app = try await SwiftWebTestFixtures.app()
        let res = await match.execute(body: nil, app: app)
        #expect(res.status == .notFound)
    }
    
    @Test func test_Router_IncorrectMethod_ReturnsMethodNotAllowed() async throws {
        let builder = RouterBuilder()
        builder.get("/users", to: emptyHandler)
        let router = builder.build()
        let match = router.match(head: HTTPRequestHead(version: .http1_1, method: .POST, uri: "/users"))
        let app = try await SwiftWebTestFixtures.app()
        let res = await match.execute(body: nil, app: app)
        #expect(res.status == .methodNotAllowed)
    }
    
    @Test func test_Router_PostRoute_IsValid() async throws {
        let builder = RouterBuilder()
        builder.post("/users", to: emptyHandler)
        let router = builder.build()
        let match = router.match(head: HTTPRequestHead(version: .http1_1, method: .POST, uri: "/users"))
        let app = try await SwiftWebTestFixtures.app()
        let res = await match.execute(body: nil, app: app)
        #expect(res.status == .ok)
    }
    
    @Test func test_Router_PatchRoute_IsValid() async throws {
        let builder = RouterBuilder()
        builder.patch("/users/:id", to: paramsEchoHandler(params: "id"))
        let router = builder.build()
        let match = router.match(head: HTTPRequestHead(version: .http1_1, method: .PATCH, uri: "/users/12"))
        let app = try await SwiftWebTestFixtures.app()
        let res = await match.execute(body: nil, app: app)
        #expect(res.status == .ok)
        #expect(res.headers["id"] == ["12"])
    }
    
    @Test func test_Router_PutRoute_IsValid() async throws {
        let builder = RouterBuilder()
        builder.put("/users/:id", to: paramsEchoHandler(params: "id"))
        let router = builder.build()
        let match = router.match(head: HTTPRequestHead(version: .http1_1, method: .PUT, uri: "/users/45"))
        let app = try await SwiftWebTestFixtures.app()
        let res = await match.execute(body: nil, app: app)
        #expect(res.status == .ok)
        #expect(res.headers["id"] == ["45"])
    }
    
    @Test func test_Router_DeleteRoute_IsValid() async throws {
        let builder = RouterBuilder()
        builder.delete("/users/:id", to: paramsEchoHandler(params: "id"))
        let router = builder.build()
        let match = router.match(head: HTTPRequestHead(version: .http1_1, method: .DELETE, uri: "/users/2"))
        let app = try await SwiftWebTestFixtures.app()
        let res = await match.execute(body: nil, app: app)
        #expect(res.status == .ok)
        #expect(res.headers["id"] == ["2"])
    }
    
    @Test func test_Router_NestedParameterRoute_IsValid() async throws {
        let builder = RouterBuilder()
        builder.patch("/posts/:post_id/comments/:comment_id", to: paramsEchoHandler(params: "post_id", "comment_id"))
        let router = builder.build()
        let match = router.match(head: HTTPRequestHead(version: .http1_1, method: .PATCH, uri: "/posts/578/comments/127"))
        let app = try await SwiftWebTestFixtures.app()
        let res = await match.execute(body: nil, app: app)
        #expect(res.status == .ok)
        #expect(res.headers["post_id"] == ["578"])
        #expect(res.headers["comment_id"] == ["127"])
    }
    
    @Test func test_Router_QueryParameters_IsValid() async throws {
        let builder = RouterBuilder()
        builder.get("/users", to: queryEchoHandler(queries: "name", "age"))
        let router = builder.build()
        let match = router.match(head: HTTPRequestHead(version: .http1_1, method: .GET, uri: "/users?name=John&age=30"))
        let app = try await SwiftWebTestFixtures.app()
        let res = await match.execute(body: nil, app: app)
        #expect(res.status == .ok)
        #expect(res.headers["name"] == ["John"])
        #expect(res.headers["age"] == ["30"])
    }
    
    @Test func test_Router_Resources_IsValid() async throws {
        let builder = RouterBuilder()
        builder.resources("/users", for: TestController.self, parameter: "user_id")
        let router = builder.build()
        let app = try await SwiftWebTestFixtures.app()

        let index = router.match(head: HTTPRequestHead(version: .http1_1, method: .GET, uri: "/users"))
        let indexRes = await index.execute(body: nil, app: app)
        #expect(indexRes.status == .ok)

        let show = router.match(head: HTTPRequestHead(version: .http1_1, method: .GET, uri: "/users/12"))
        #expect(show.params["user_id"] == "12")
        let showRes = await show.execute(body: nil, app: app)
        #expect(showRes.status == .ok)

        let new = router.match(head: HTTPRequestHead(version: .http1_1, method: .GET, uri: "/users/new"))
        let newRes = await new.execute(body: nil, app: app)
        #expect(newRes.status == .ok)

        let create = router.match(head: HTTPRequestHead(version: .http1_1, method: .POST, uri: "/users"))
        let createRes = await create.execute(body: nil, app: app)
        #expect(createRes.status == .ok)

        let edit = router.match(head: HTTPRequestHead(version: .http1_1, method: .GET, uri: "/users/888/edit"))
        #expect(edit.params["user_id"] == "888")
        let editRes = await edit.execute(body: nil, app: app)
        #expect(editRes.status == .ok)

        let update_patch = router.match(head: HTTPRequestHead(version: .http1_1, method: .PATCH, uri: "/users/78"))
        #expect(update_patch.params["user_id"] == "78")
        let update_patch_res = await update_patch.execute(body: nil, app: app)
        #expect(update_patch_res.status == .ok)

        let update_put = router.match(head: HTTPRequestHead(version: .http1_1, method: .PUT, uri: "/users/21"))
        #expect(update_put.params["user_id"] == "21")
        let update_put_res = await update_put.execute(body: nil, app: app)
        #expect(update_put_res.status == .ok)

        let delete = router.match(head: HTTPRequestHead(version: .http1_1, method: .DELETE, uri: "/users/44"))
        #expect(delete.params["user_id"] == "44")
        let delete_res = await delete.execute(body: nil, app: app)
        #expect(delete_res.status == .ok)
    }
    
    @Test func test_Router_NestedResources_IsValid() async throws {
        let builder = RouterBuilder()
        builder.resources("/users", for: TestController.self) { router in
            router.resources("/posts", for: TestController.self, parameter: "post_id")
        }
        let router = builder.build()
        let app = try await SwiftWebTestFixtures.app()

        let index = router.match(head: HTTPRequestHead(version: .http1_1, method: .GET, uri: "/users/14/posts"))
        #expect(index.params["id"] == "14")
        let indexRes = await index.execute(body: nil, app: app)
        #expect(indexRes.status == .ok)

        let show = router.match(head: HTTPRequestHead(version: .http1_1, method: .GET, uri: "/users/78/posts/12"))
        #expect(show.params["id"] == "78")
        #expect(show.params["post_id"] == "12")
        let showRes = await show.execute(body: nil, app: app)
        #expect(showRes.status == .ok)

        let new = router.match(head: HTTPRequestHead(version: .http1_1, method: .GET, uri: "/users/8992/posts/new"))
        #expect(new.params["id"] == "8992")
        let newRes = await new.execute(body: nil, app: app)
        #expect(newRes.status == .ok)

        let create = router.match(head: HTTPRequestHead(version: .http1_1, method: .POST, uri: "/users/22/posts"))
        #expect(create.params["id"] == "22")
        let createRes = await create.execute(body: nil, app: app)
        #expect(createRes.status == .ok)

        let edit = router.match(head: HTTPRequestHead(version: .http1_1, method: .GET, uri: "/users/828/posts/134/edit"))
        #expect(edit.params["id"] == "828")
        #expect(edit.params["post_id"] == "134")
        let editRes = await edit.execute(body: nil, app: app)
        #expect(editRes.status == .ok)

        let update_patch = router.match(head: HTTPRequestHead(version: .http1_1, method: .PATCH, uri: "/users/32/posts/98"))
        #expect(update_patch.params["id"] == "32")
        #expect(update_patch.params["post_id"] == "98")
        let update_patch_res = await update_patch.execute(body: nil, app: app)
        #expect(update_patch_res.status == .ok)

        let update_put = router.match(head: HTTPRequestHead(version: .http1_1, method: .PUT, uri: "/users/21/posts/78"))
        #expect(update_put.params["id"] == "21")
        #expect(update_put.params["post_id"] == "78")
        let update_put_res = await update_put.execute(body: nil, app: app)
        #expect(update_put_res.status == .ok)

        let delete = router.match(head: HTTPRequestHead(version: .http1_1, method: .DELETE, uri: "/users/09/posts/167"))
        #expect(delete.params["id"] == "09")
        #expect(delete.params["post_id"] == "167")
        let delete_res = await delete.execute(body: nil, app: app)
        #expect(delete_res.status == .ok)
    }
    
    @Test func test_Router_Namespace_IsValid() async throws {
        let builder = RouterBuilder()
        builder.namespace("/api") { router in
            router.get("/hello", to: emptyHandler)
        }
        let router = builder.build()
        let match = router.match(head: HTTPRequestHead(version: .http1_1, method: .GET, uri: "/api/hello"))
        let app = try await SwiftWebTestFixtures.app()
        let res = await match.execute(body: nil, app: app)
        #expect(res.status == .ok)
    }

    @Test func test_Router_NestedNamespace_IsValid() async throws {
        let builder = RouterBuilder()
        builder.namespace("/api") { router in
            router.namespace("/v1") { RouterBuilder in
                router.get("/hello", to: emptyHandler)
            }
            router.get("/documentation", to: emptyHandler)
        }
        let router = builder.build()
        let app = try await SwiftWebTestFixtures.app()

        let documentationMatch = router.match(head: HTTPRequestHead(version: .http1_1, method: .GET, uri: "/api/documentation"))
        let documentationRes = await documentationMatch.execute(body: nil, app: app)
        #expect(documentationRes.status == .ok)

        let helloMatch = router.match(head: HTTPRequestHead(version: .http1_1, method: .GET, uri: "/api/v1/hello"))
        let helloRes = await helloMatch.execute(body: nil, app: app)
        #expect(helloRes.status == .ok)
    }
    
    @Test func test_Router_RoutePrecendence_IsValid() async throws {
        let builder = RouterBuilder()
        builder.get("/users/new", to: emptyHandler)
        builder.get("/users/:id", to: paramsEchoHandler(params: "id"))
        let router = builder.build()
        let app = try await SwiftWebTestFixtures.app()

        let dynamicRoute = router.match(head: HTTPRequestHead(version: .http1_1, method: .GET, uri: "/users/12"))
        let dynamicRes = await dynamicRoute.execute(body: nil, app: app)
        #expect(dynamicRes.status == .ok)
        #expect(dynamicRes.headers["id"] == ["12"])

        let staticRoute = router.match(head: HTTPRequestHead(version: .http1_1, method: .GET, uri: "/users/new"))
        let staticRes = await staticRoute.execute(body: nil, app: app)
        #expect(staticRes.status == .ok)
        #expect(staticRes.headers["id"].isEmpty)
    }

    @Test func test_Router_GlobalMiddleware_IsValid() async throws {
        let builder = RouterBuilder(globalMiddleware: [DummyMiddleware()])
        builder.get("/hello", to: emptyHandler)
        let router = builder.build()
        let app = try await SwiftWebTestFixtures.app()
        let match = router.match(head: HTTPRequestHead(version: .http1_1, method: .GET, uri: "/hello"))
        let res = await match.execute(body: nil, app: app)
        #expect(res.headers["X-Dummy-Middleware-Used"] == ["true"])
    }

    @Test func test_Router_LocalMiddleware_IsValid() async throws {
        let builder = RouterBuilder()
        builder.group(DummyMiddleware()) { router in
            router.get("/dummy", to: emptyHandler)
        }
        let router = builder.build()
        let app = try await SwiftWebTestFixtures.app()
        let match = router.match(head: HTTPRequestHead(version: .http1_1, method: .GET, uri: "/dummy"))
        let res = await match.execute(body: nil, app: app)
        #expect(res.headers["X-Dummy-Middleware-Used"] == ["true"])
    }

    @Test func test_Router_GroupMiddleware_IsValid() async throws {
        let builder = RouterBuilder()
        builder.group(DummyMiddleware(), SecondDummyMiddleware()) { router in
            router.get("/dummy", to: emptyHandler)
        }
        let router = builder.build()
        let app = try await SwiftWebTestFixtures.app()
        let match = router.match(head: HTTPRequestHead(version: .http1_1, method: .GET, uri: "/dummy"))
        let res = await match.execute(body: nil, app: app)
        #expect(res.headers["X-Dummy-Middleware-Used"] == ["true"])
        #expect(res.headers["X-Second-Dummy-Middleware-Used"] == ["true"])
    }

    @Test func test_Router_UseMiddleware_IsValid() async throws {
        let builder = RouterBuilder()
        builder.use(DummyMiddleware())
        builder.get("/dummy", to: emptyHandler)
        let router = builder.build()
        let app = try await SwiftWebTestFixtures.app()
        let match = router.match(head: HTTPRequestHead(version: .http1_1, method: .GET, uri: "/dummy"))
        let res = await match.execute(body: nil, app: app)
        #expect(res.headers["X-Dummy-Middleware-Used"] == ["true"])
    }

    @Test func test_Router_MiddlewareApplication_IsValid() async throws {
        let builder = RouterBuilder()
        builder.group(DummyMiddleware()) { router in
            router.get("/one", to: emptyHandler)
            builder.group(SecondDummyMiddleware()) { builder in
                router.get("/two", to: emptyHandler)
            }
        }
        let router = builder.build()
        let app = try await SwiftWebTestFixtures.app()
        let one = router.match(head: HTTPRequestHead(version: .http1_1, method: .GET, uri: "/one"))
        let two = router.match(head: HTTPRequestHead(version: .http1_1, method: .GET, uri: "/two"))
        let resOne = await one.execute(body: nil, app: app)
        let resTwo = await two.execute(body: nil, app: app)
        #expect(resOne.headers["X-Dummy-Middleware-Used"] == ["true"])
        #expect(resOne.headers["X-Second-Dummy-Middleware-Used"] == [])

        #expect(resTwo.headers["X-Dummy-Middleware-Used"] == ["true"])
        #expect(resTwo.headers["X-Second-Dummy-Middleware-Used"] == ["true"])
    }
}
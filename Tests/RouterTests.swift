//
//  RouterTests.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/16/25.
//

import Testing
@testable import SwiftWeb

struct TestController: Controller {}

@Suite struct RouterTests {
    let builder = RouterBuilder()
    
    let emptyHandler: Handler = { _ in Response(status: .ok) }
    
    
    @Test func testGet() {
        builder.get("/users", to: emptyHandler)
        let router = builder.build()
        let match = router.match(uri: "/users", method: .GET)
        #expect(match != nil)
    }
    
    @Test func testLongNonexistentRoute() {
        builder.get("/users", to: emptyHandler)
        let router = builder.build()
        let extraComponent = router.match(uri: "/users/info", method: .GET)
        let extraParameter = router.match(uri: "/users/23", method: .GET)
        #expect(extraComponent == nil)
        #expect(extraParameter == nil)
    }
    
    @Test func testShortNonexistentRoute() {
        builder.get("/users/comments/info", to: emptyHandler)
        let router = builder.build()
        let shortRoute = router.match(uri: "/users", method: .GET)
        let shortParameterRoute = router.match(uri: "/users/comments/124", method: .GET)
        #expect(shortRoute == nil)
        #expect(shortParameterRoute == nil)
    }
    
    @Test func testNonestistentMethod() {
        builder.get("/users", to: emptyHandler)
        let router = builder.build()
        let postMatch = router.match(uri: "/users", method: .POST)
        #expect(postMatch == nil)
    }
    
    @Test func testPost() {
        builder.post("/users", to: emptyHandler)
        let router = builder.build()
        let match = router.match(uri: "/users", method: .POST)
        #expect(match != nil)
    }
    
    @Test func testPatch() {
        builder.patch("/users/:id", to: emptyHandler)
        let router = builder.build()
        let match = router.match(uri: "/users/432", method: .PATCH)
        #expect(match != nil)
    }
    
    @Test func testPut() {
        builder.put("/users/:id", to: emptyHandler)
        let router = builder.build()
        let match = router.match(uri: "/users/89", method: .PUT)
        #expect(match != nil)
    }
    
    @Test func testDelete() {
        builder.delete("/users/:id", to: emptyHandler)
        let router = builder.build()
        let match = router.match(uri: "/users/673", method: .DELETE)
        #expect(match != nil)
    }
    
    @Test func testParameter() {
        builder.patch("/posts/:id", to: emptyHandler)
        let router = builder.build()
        let match = router.match(uri: "/posts/123", method: .PATCH)
        #expect(match != nil)
        #expect(match?.params["id"] == "123")
    }
    
    @Test func testNestedParameter() {
        builder.patch("/posts/:post_id/comments/:comment_id", to: emptyHandler)
        let router = builder.build()
        let match = router.match(uri: "/posts/578/comments/127", method: .PATCH)
        #expect(match != nil)
        #expect(match?.params["post_id"] == "578")
        #expect(match?.params["comment_id"] == "127")
    }
    
    @Test func testQueryParameter() {
        builder.get("/users", to: emptyHandler)
        let router = builder.build()
        let match = router.match(uri: "/users?name=John&age=30", method: .GET)
        #expect(match != nil)
        #expect(match?.query["name"] == "John")
        #expect(match?.query["age"] == "30")
    }
    
    @Test func testResources() {
        builder.resources("/users", for: TestController.self, parameter: "user_id")
        let router = builder.build()
        let index = router.match(uri: "/users", method: .GET)
        let show = router.match(uri: "/users/12", method: .GET)
        let new = router.match(uri: "/users/new", method: .GET)
        let create = router.match(uri: "/users", method: .POST)
        let edit = router.match(uri: "/users/888/edit", method: .GET)
        let update_patch = router.match(uri: "/users/78", method: .PATCH)
        let update_put = router.match(uri: "/users/21", method: .PUT)
        let delete = router.match(uri: "/users/44", method: .DELETE)
        #expect(index != nil)
        #expect(show != nil)
        #expect(show?.params["user_id"] == "12")
        #expect(new != nil)
        #expect(create != nil)
        #expect(edit != nil)
        #expect(edit?.params["user_id"] == "888")
        #expect(update_patch != nil)
        #expect(update_patch?.params["user_id"] == "78")
        #expect(update_put != nil)
        #expect(update_put?.params["user_id"] == "21")
        #expect(delete != nil)
        #expect(delete?.params["user_id"] == "44")
    }
    
    @Test func testNestedResources() {
        builder.resources("/users", for: TestController.self) { router in
            router.resources("/posts", for: TestController.self, parameter: "post_id")
        }
        let router = builder.build()
        let index = router.match(uri: "/users/14/posts", method: .GET)
        let show = router.match(uri: "/users/78/posts/12", method: .GET)
        let new = router.match(uri: "/users/8992/posts/new", method: .GET)
        let create = router.match(uri: "/users/22/posts", method: .POST)
        let edit = router.match(uri: "/users/828/posts/134/edit", method: .GET)
        let update_patch = router.match(uri: "/users/32/posts/98", method: .PATCH)
        let update_put = router.match(uri: "/users/21/posts/78", method: .PUT)
        let delete = router.match(uri: "/users/09/posts/167", method: .DELETE)
        #expect(index != nil)
        #expect(index?.params["id"] == "14")
        #expect(show != nil)
        #expect(show?.params["id"] == "78")
        #expect(show?.params["post_id"] == "12")
        #expect(new != nil)
        #expect(new?.params["id"] == "8992")
        #expect(create != nil)
        #expect(create?.params["id"] == "22")
        #expect(edit != nil)
        #expect(edit?.params["id"] == "828")
        #expect(edit?.params["post_id"] == "134")
        #expect(update_patch != nil)
        #expect(update_patch?.params["id"] == "32")
        #expect(update_patch?.params["post_id"] == "98")
        #expect(update_put != nil)
        #expect(update_put?.params["id"] == "21")
        #expect(update_put?.params["post_id"] == "78")
        #expect(delete != nil)
        #expect(delete?.params["id"] == "09")
        #expect(delete?.params["post_id"] == "167")
    }
    
    @Test func testResourcesOnly() {
        builder.resources("/users", for: TestController.self, only: [ .show, .create])
        let router = builder.build()
        let index = router.match(uri: "/users", method: .GET)
        let show = router.match(uri: "/users/12", method: .GET)
        let new = router.match(uri: "/users/new", method: .GET)
        let create = router.match(uri: "/users", method: .POST)
        let edit = router.match(uri: "/users/888/edit", method: .GET)
        let update_patch = router.match(uri: "/users/78", method: .PATCH)
        let update_put = router.match(uri: "/users/21", method: .PUT)
        let delete = router.match(uri: "/users/44", method: .DELETE)
        #expect(index == nil)
        #expect(show != nil)
        #expect(show?.params["id"] == "12")
        #expect(new != nil)
        #expect(new?.params["id"] == "new")
        #expect(create != nil)
        #expect(edit == nil)
        #expect(update_patch == nil)
        #expect(update_put == nil)
        #expect(delete == nil)
    }
    
    @Test func testResourcesExcept() {
        builder.resources("/users", for: TestController.self, except: [ .show, .create, .delete ])
        let router = builder.build()
        let index = router.match(uri: "/users", method: .GET)
        let show = router.match(uri: "/users/12", method: .GET)
        let new = router.match(uri: "/users/new", method: .GET)
        let create = router.match(uri: "/users", method: .POST)
        let edit = router.match(uri: "/users/888/edit", method: .GET)
        let update_patch = router.match(uri: "/users/78", method: .PATCH)
        let update_put = router.match(uri: "/users/21", method: .PUT)
        let delete = router.match(uri: "/users/44", method: .DELETE)
        #expect(index != nil)
        #expect(show == nil)
        #expect(new != nil)
        #expect(create == nil)
        #expect(edit != nil)
        #expect(edit?.params["id"] == "888")
        #expect(update_patch != nil)
        #expect(update_patch?.params["id"] == "78")
        #expect(update_put != nil)
        #expect(update_put?.params["id"] == "21")
        #expect(delete == nil)
    }
    
    @Test func testNamespace() {
        builder.namespace("/api/v1") { router in
            router.get("/hello", to: emptyHandler)
        }
        let router = builder.build()
        let match = router.match(uri: "/api/v1/hello", method: .GET)
        #expect(match != nil)
    }
    
    @Test func testRoutePrecedence() {
        builder.get("/users/:id", to: emptyHandler)
        builder.get("/users/new", to: emptyHandler)
        let router = builder.build()
        let dynamicRoute = router.match(uri: "/users/12", method: .GET)
        let staticRoute = router.match(uri: "/users/new", method: .GET)
        #expect(dynamicRoute != nil)
        #expect(dynamicRoute?.params["id"] == "12")
        #expect(staticRoute != nil)
        #expect(staticRoute?.params["id"] == nil)
    }
}

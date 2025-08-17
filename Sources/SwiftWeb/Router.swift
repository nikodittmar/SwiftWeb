//
//  Router.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/15/25.
//
import Foundation
import NIOHTTP1
import SwiftWebCore
import NIO

public typealias Handler = @Sendable (_ req: Request) async throws -> Response

public struct MatchedRoute: Sendable {
    let head: HTTPRequestHead
    let handler: Handler
    let params: [String: String]
    let query: [String: String]
    let middleware: [Middleware]

    public func execute(body: ByteBuffer?, app: Application) async -> Response {
        let request = Request(head: head, body: body, params: params, query: query, app: app)

        let responder = self.middleware.reversed().reduce(self.handler) { (nextHandler, middleware) in
            return { req in
                try await middleware.handle(req: req, next: nextHandler)
            }
        }

        do {
            return try await responder(request)
        } catch {
            return .error(error, on: app, version: head.version)
        }
    }
}

private final class RouteNode: Sendable {
    let children: [String: RouteNode]
    let handlers: [String: Handler]
    let parameter: (name: String, node: RouteNode)?
    let middleware: [Middleware]
    
    init(children: [String:RouteNode], handlers: [String: Handler], parameter: (name: String, node: RouteNode)?, middleware: [Middleware]) {
        self.children = children
        self.handlers = handlers
        self.parameter = parameter
        self.middleware = middleware
    }
}

private final class MutableRouteNode {
    var children: [String: MutableRouteNode] = [:]
    var handlers: [String: Handler] = [:]
    var parameter: (name: String, node: MutableRouteNode)?
    var middleware: [Middleware] = []
}

public final class Router: Sendable {
    private let root: RouteNode

    private let globalMiddleware: [Middleware]
    
    fileprivate init(root: RouteNode, globalMiddleware: [Middleware]) {
        self.root = root
        self.globalMiddleware = globalMiddleware
    }
    
    public func printRoutes() {
        printSubtree(for: root)
    }
    
    private func printSubtree(for tree: RouteNode?, path: String = "") {
        guard let tree = tree else { return }
        
        for method in tree.handlers.keys {
            let displayPath = path.isEmpty ? "/" : path
            let paddedMethod = method.padding(toLength: 8, withPad: " ", startingAt: 0)
            print("\(paddedMethod) \(displayPath)")
        }
        
        for (name, child) in tree.children {
            printSubtree(for: child, path: "\(path)/\(name)")
        }
        
        if let parameter = tree.parameter {
            printSubtree(for: parameter.node, path: "\(path)/:\(parameter.name)")
        }
    
    }
    
    public func match(head: HTTPRequestHead) -> MatchedRoute {
        let uri = head.uri
        let method = head.method

        guard let uriComponents = URLComponents(string: uri) else {
            return MatchedRoute(
                head: head, 
                handler: { req in throw SwiftWebError(type: .badRequest, reason: "The provided URI string '\(uri)' is malformed and could not be parsed.") }, 
                params: [:], 
                query: [:], 
                middleware: globalMiddleware
            )
        }
            
        let query: [String: String] = uriComponents.queryItems?.reduce(into: [:]) { result, item in
            result[item.name] = item.value
        } ?? [:]
             
        var params: [String: String] = [:]

        let pathComponents: [String] = uriComponents.path.split(separator: "/").map(String.init)
        
        var current = root

        for component in pathComponents {
            if let child = current.children[component] {
                current = child
            } else if let parameter = current.parameter {
                current = parameter.node
                params[parameter.name] = component
            } else {
                return MatchedRoute(
                    head: head, 
                    handler: { req in throw SwiftWebError(type: .notFound, reason: "No route found for path '\(uriComponents.path)'. Failed to match segment '\(component)'.") }, 
                    params: [:], 
                    query: query, 
                    middleware: globalMiddleware
                )
            }
        }
        
        if current.handlers.isEmpty {
            return MatchedRoute(
                head: head,
                handler: { req in throw SwiftWebError(type: .notFound, reason: "No route found for path '\(uriComponents.path)'.") },
                params: [:],
                query: query,
                middleware: globalMiddleware
            )
        }
        
        guard let handler = current.handlers[method.rawValue] else {
            return MatchedRoute(
                head: head, 
                handler: { req in throw SwiftWebError(type: .methodNotAllowed, reason: "A route exists for path '\(uriComponents.path)', but not for method '\(method.rawValue)'.") }, 
                params: [:], 
                query: query, 
                middleware: globalMiddleware
            )
        }

        let collectedMiddleware = self.globalMiddleware + current.middleware
        return MatchedRoute(head: head, handler: handler, params: params, query: query, middleware: collectedMiddleware)
    }
}

public final class RouterBuilder {
    public init(globalMiddleware: [Middleware] = []) {
        self.globalMiddleware = globalMiddleware
    }

    private let globalMiddleware: [Middleware]
    
    private var root: MutableRouteNode = MutableRouteNode()
    private var middlewareStack: [[Middleware]] = [[]]
    private var pathPrefixStack: [String] = []
    
    private func addRoute(path: String, method: HTTPMethod, handler: @escaping Handler) {
        let fullPath = (pathPrefixStack + [path]).joined()
        let components: [String] = fullPath.split(separator: "/").map(String.init)
        
        var parameters: Set<String> = []
        
        var current: MutableRouteNode = root
        for component in components {
            if component.hasPrefix(":") {
                let name = String(component.dropFirst())
                if parameters.contains(name) {
                    preconditionFailure("""
                    Duplicate parameter: Cannot define route with duplicate parameter.
                    Duplicate parameter: ':\(name)'
                    Path: '\(path)'
                    """)
                } else {
                    parameters.insert(name)
                }
                if let parameter = current.parameter {
                    guard parameter.name == name else {
                        preconditionFailure("""
                        Ambiguous route definition: Cannot define routes with different parameter names at the same level.
                        Existing parameter: ':\(parameter.name)'
                        New conflicting parameter: ':\(name)'
                        Path: '\(path)'
                        """)
                    }
                    current = parameter.node
                } else {
                    let parameter: (name: String, node: MutableRouteNode) = (name: name, node: MutableRouteNode())
                    current.parameter = parameter
                    current = parameter.node
                }
            } else {
                if let child = current.children[component] {
                    current = child
                } else {
                    let child = MutableRouteNode()
                    current.children[component] = child
                    current = child
                }
            }
        }

        current.middleware = self.middlewareStack.flatMap { $0 }
        
        if current.handlers[method.rawValue] != nil {
            preconditionFailure("Duplicate route: '\(method.rawValue) \(path)' has already been defined.")
        }
        current.handlers[method.rawValue] = handler
    }

    public func use(_ middleware: Middleware) {
        self.middlewareStack[self.middlewareStack.count - 1].append(middleware)
    }
    
    public func get(_ path: String, to handler: @escaping Handler) {
        addRoute(path: path, method: .GET, handler: handler)
    }
    
    public func post(_ path: String, to handler: @escaping Handler) {
        addRoute(path: path, method: .POST, handler: handler)
    }
    
    public func patch(_ path: String, to handler: @escaping Handler) {
        addRoute(path: path, method: .PATCH, handler: handler)
    }
    
    public func put(_ path: String, to handler: @escaping Handler) {
        addRoute(path: path, method: .PUT, handler: handler)
    }
    
    public func delete(_ path: String, to handler: @escaping Handler) {
        addRoute(path: path, method: .DELETE, handler: handler)
    }
    
    public func namespace(_ prefix: String, _ closure: (RouterBuilder) -> Void) {
        pathPrefixStack.append(prefix)
        closure(self)
        pathPrefixStack.removeLast()
    }
    
    public func resources<T: ResourcefulController>(
        _ path: String,
        for: T.Type,
        parameter: String = "id"
    ) {
        let controller = T()
        
        get(path, to: controller.index)
        get("\(path)/:\(parameter)", to: controller.show)
        get("\(path)/new", to: controller.new)
        post(path, to: controller.create)
        get("\(path)/:\(parameter)/edit", to: controller.edit)
        patch("\(path)/:\(parameter)", to: controller.update)
        put("\(path)/:\(parameter)", to: controller.update)
        delete("\(path)/:\(parameter)", to: controller.destroy)
    }
    
    public func resources<T: ResourcefulController>(
        _ path: String,
        for: T.Type,
        parameter: String = "id",
        _ nesting: (RouterBuilder) -> Void
    ) {
        resources(path, for: T.self, parameter: parameter)
        pathPrefixStack.append("\(path)/:\(parameter)/")
        nesting(self)
        pathPrefixStack.removeLast()
    }

    public func group(_ middleware: Middleware..., routes: (RouterBuilder) -> Void) {
        self.middlewareStack.append(middleware)
        routes(self)
        self.middlewareStack.removeLast()
    }
    
    public func build() -> Router {
        return Router(root: convertNode(self.root), globalMiddleware: globalMiddleware)
    }
    
    private func convertNode(_ node: MutableRouteNode) -> RouteNode {
        let children = convertChildren(node.children)
        let parameter = node.parameter.map { (name: $0.name, node: convertNode($0.node)) }
        return RouteNode(children: children, handlers: node.handlers, parameter: parameter, middleware: node.middleware)
    }
    
    private func convertChildren(_ mutableChildren: [String : MutableRouteNode]) -> [String: RouteNode] {
        return mutableChildren.mapValues { convertNode($0) }
    }
}

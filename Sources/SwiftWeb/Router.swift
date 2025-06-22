//
//  Router.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/15/25.
//
import Foundation
import NIOHTTP1

public typealias Handler = @Sendable (_ req: Request) async -> Response

private final class RouteNode: Sendable {
    let children: [String: RouteNode]
    let handlers: [String: Handler]
    let parameter: (name: String, node: RouteNode)?
    
    init(children: [String:RouteNode], handlers: [String: Handler], parameter: (name: String, node: RouteNode)?) {
        self.children = children
        self.handlers = handlers
        self.parameter = parameter
    }
}

private final class MutableRouteNode {
    var children: [String: MutableRouteNode] = [:]
    var handlers: [String: Handler] = [:]
    var parameter: (name: String, node: MutableRouteNode)?
}

final class Router: Sendable {
    private let root: RouteNode
    
    fileprivate init(root: RouteNode) {
        self.root = root
    }
    
    public func printRoutes() {
        print("------ Registered Routes ------")
        printSubtree(for: root)
        print("-------------------------------")
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
    
    public func match(uri: String, method: HTTPMethod) -> (handler: Handler, params: [String: String], query: [String: String])? {
    
        let uriComponents = URLComponents(string: uri)
        
        let pathComponents: [String] = uriComponents?.path.split(separator: "/").map(String.init) ?? []
    
        var query: [String: String] = [:]
        
        for queryItem in uriComponents?.queryItems ?? [] {
            query[queryItem.name] = queryItem.value ?? ""
        }
             
        var params: [String: String] = [:]
        
        var current = root
        for component in pathComponents {
            if let child = current.children[component] {
                current = child
            } else if let parameter = current.parameter {
                current = parameter.node
                params[parameter.name] = component
            } else {
                return nil
            }
        }
        
        if let handler = current.handlers[method.rawValue] {
            return (handler: handler, params: params, query: query)
        } else {
            return nil
        }
    }
}

final class RouterBuilder {
    private var root: MutableRouteNode = MutableRouteNode()
    private var pathPrefix: String = ""
    
    private func addRoute(path: String, method: HTTPMethod, handler: @escaping Handler) {
        let path: String = pathPrefix + path
        let components: [String] = path.split(separator: "/").map(String.init)
        
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
        
        if current.handlers[method.rawValue] != nil {
            preconditionFailure("Duplicate route: '\(method.rawValue) \(path)' has already been defined.")
        }
        current.handlers[method.rawValue] = handler
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
        pathPrefix = prefix + "/"
        closure(self)
        pathPrefix = ""
    }
    
    public enum ResourceAction {
        case index, show, new, create, edit, update, delete
    }
    
    public func resources<T: Controller>(
        _ path: String,
        for: T.Type,
        only: Set<ResourceAction>? = nil,
        except: Set<ResourceAction>? = nil,
        parameter: String = "id"
    ) {
        if (only != nil && except != nil) {
            preconditionFailure("Cannot specify both only and except for resources on '\(path)'")
        }
        
        var actions: Set<ResourceAction> = []
        let allActions: Set<ResourceAction> = [ .index, .show, .new, .create, .edit, .update, .delete ]
        
        if let only = only {
            actions = Set(only)
        } else if let except = except {
            actions = allActions.subtracting(except)
        } else {
            actions = allActions
        }
        
        let controller = T()
        
        if actions.contains(.index) { get(path, to: controller.index) }
        if actions.contains(.show) { get("\(path)/:\(parameter)", to: controller.show) }
        if actions.contains(.new) { get("\(path)/new", to: controller.new) }
        if actions.contains(.create) { post(path, to: controller.create) }
        if actions.contains(.edit) { get("\(path)/:\(parameter)/edit", to: controller.update) }
        if actions.contains(.update) {
            patch("\(path)/:\(parameter)", to: controller.update)
            put("\(path)/:\(parameter)", to: controller.update)
        }
        if actions.contains(.delete) { delete("\(path)/:\(parameter)", to: controller.destroy) }
    }
    
    public func resources<T: Controller>(
        _ path: String,
        for: T.Type,
        only: Set<ResourceAction>? = nil,
        except: Set<ResourceAction>? = nil,
        parameter: String = "id",
        _ nesting: (RouterBuilder) -> Void
    ) {
        resources(path, for: T.self, only: only, except: except, parameter: parameter)
        pathPrefix = "\(path)/:\(parameter)/"
        nesting(self)
        pathPrefix = ""
    }
    
    public func build() -> Router {
        return Router(root: convertNode(self.root))
    }
    
    private func convertNode(_ node: MutableRouteNode) -> RouteNode {
        if let parameter = node.parameter {
            return RouteNode(children: convertChildren(node.children), handlers: node.handlers, parameter: (name: parameter.name, node: convertNode(parameter.node)))
        } else {
            return RouteNode(children: convertChildren(node.children), handlers: node.handlers, parameter: nil)
        }
    }
    
    private func convertChildren(_ mutableChildren: [String : MutableRouteNode]) -> [String: RouteNode] {
        var children: [String: RouteNode] = [:]
        for (component, node) in mutableChildren {
            children[component] = convertNode(node)
        }
        
        return children
    }
}

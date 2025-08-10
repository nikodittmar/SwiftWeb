import SwiftWeb

struct HelloController: Controller {
    func hello(req: Request) throws -> Response {
        return try .view("hello", on: req)
    }
}
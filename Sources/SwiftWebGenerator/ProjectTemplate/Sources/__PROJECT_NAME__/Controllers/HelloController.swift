import SwiftWeb

struct HelloController: Controller {
    @Sendable func welcome(req: Request) -> Response {
        struct Context: Codable {
            let title: String
        }
        return .view("welcome", with: Context(title: "SwiftWeb!"), on: req)
    }
}

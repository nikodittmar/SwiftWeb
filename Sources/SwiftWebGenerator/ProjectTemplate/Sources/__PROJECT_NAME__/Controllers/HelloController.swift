import SwiftWeb

struct HelloController: Controller {
    @Sendable func welcome(req: Request) -> Response {
        struct Context: Codable {
            let title: String
        }
        do {
            return try .view("welcome", with: Context(title: "SwiftWeb!"), on: req)
        } catch {
            print("[SwiftWeb] ❌ Error rendering view: \(error)")
            return .html("error")
        }
    }
}

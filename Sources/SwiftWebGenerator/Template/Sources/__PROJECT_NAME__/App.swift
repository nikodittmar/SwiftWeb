import Foundation
import SwiftWeb
import SwiftDB

@main
struct Main {
    static func main() async {
        await SwiftWeb<AppConfig>.main()
    }
}

struct AppConfig: SwiftWebConfig {
    static let projectName: String = "__PROJECT_NAME__"

    static let migrations: [Migration.Type] = []
    
    public static let viewsDirectory: URL = Bundle.module.url(forResource: "Views", withExtension: nil)!
    
    public static let publicDirectory: URL = Bundle.module.url(forResource: "Public", withExtension: nil)!
    
    static func configureRoutes() -> Router { return routes() }
    
    static let port: Int = 8080
}
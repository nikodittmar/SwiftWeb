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
    
    static let viewsDirectory: URL = {
        guard let url = Bundle.module.url(forResource: "Views", withExtension: nil) else {
            fatalError("Views directory not found in bundle. Check your Package.swift resources.")
        }
        return url
    }()
    
    static func configureRoutes() -> Router { return routes() }
    
    static let port: Int = 8080
}
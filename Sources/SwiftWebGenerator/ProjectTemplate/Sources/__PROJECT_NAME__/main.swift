import Foundation
import SwiftWeb
import SwiftDB

struct AppConfig: ApplicationConfig {
    static var migrations: [Migration.Type] = []
    
    static var viewsDirectory: URL = Bundle.module.url(forResource: "Views", withExtension: nil)
    
    static func configureRoutes() -> Router { return routes() }
    
    static let port: Int = 8080
}

CLI<AppConfig>.main()

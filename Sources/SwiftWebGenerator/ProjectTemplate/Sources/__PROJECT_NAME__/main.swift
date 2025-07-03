import Foundation
import SwiftWeb
import SwiftDB

struct AppConfig: ApplicationConfig {
    static let migrations: [Migration.Type] = []
    
    static let viewsDirectory: URL = Bundle.module.url(forResource: "Views", withExtension: nil)
    
    static func configureRoutes() -> Router { return routes() }
    
    static let port: Int = 8080

    static let dotEnvPath: URL = FileManager.default.currentDirectoryPath + "/.env"
}

CLI<AppConfig>.main()

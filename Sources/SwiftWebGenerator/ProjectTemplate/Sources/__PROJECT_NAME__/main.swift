import SwiftWeb
import SwiftDB

struct AppConfig: ApplicationConfig {
    static var migrations: [Migration] = []
    
    static func configureRoutes() -> Router { return routes() }
}

CLI<AppConfig>.main()

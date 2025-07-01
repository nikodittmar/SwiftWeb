import SwiftWeb
import SwiftView
import SwiftDB
import NIO

let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

let router: Router = routes()

let db: Database = Database(eventLoopGroup: eventLoopGroup)

db.run()

guard let viewsDirectory = Bundle.module.url(forResource: "Views", withExtension: nil) else {
    fatalError("[SwiftWeb] ❌ Could not find the Views directory! Check your Package.swift resources.")
}
let views: Views = Views(viewsDirectory: viewsDirectory)

let application = Application(
    router: router,
    db: db,
    views: views,
    eventLoopGroup: eventLoopGroup
)

try! application.run(port: 3000)

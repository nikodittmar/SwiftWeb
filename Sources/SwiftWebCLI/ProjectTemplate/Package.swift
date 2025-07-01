// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "__PROJECT_NAME__",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/nikodittmar/SwiftWeb.git", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "__PROJECT_NAME__",
            dependencies: [
                .product(name: "SwiftWeb", package: "SwiftWeb"),
                .product(name: "SwiftView", package: "SwiftWeb")
            ],
            resources: [.copy("Views")]
        )
    ]
)

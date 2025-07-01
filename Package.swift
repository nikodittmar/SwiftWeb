// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftWeb",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(name: "SwiftDB", targets: ["SwiftDB"]),
        .library(name: "SwiftWeb", targets: ["SwiftWeb"]),
        .library(name: "SwiftView", targets: ["SwiftView"]),
        .executable(name: "swiftweb", targets: ["SwiftWebCLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.59.0"),
        .package(url: "https://github.com/vapor/postgres-nio.git", from: "1.21.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        .target(name: "SwiftView", dependencies: []),
        .target(name: "SwiftDB", dependencies: [
            .product(name: "PostgresNIO", package: "postgres-nio"),
        ]),
        .target(name: "SwiftWeb", dependencies: [
            .product(name: "NIO", package: "swift-nio"),
            .product(name: "NIOHTTP1", package: "swift-nio"),
            "SwiftDB",
            "SwiftView"
        ]),
        .executableTarget(
            name: "SwiftWebCLI",
            dependencies: [
                "SwiftWeb",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            resources: [
                .copy("ProjectTemplate")
            ]
        ),
        .testTarget(
            name: "SwiftWebTests",
            dependencies: ["SwiftWeb"]
        ),
        .testTarget(
            name: "SwiftDBTests",
            dependencies: ["SwiftDB"]
        ),
        .testTarget(
            name: "SwiftViewTests",
            dependencies: ["SwiftView"]
        )
    ]
)

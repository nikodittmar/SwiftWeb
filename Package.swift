// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftWeb",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .library(name: "SwiftDB", targets: ["SwiftDB"]),
        .library(name: "SwiftWeb", targets: ["SwiftWeb"]),
        .library(name: "SwiftView", targets: ["SwiftView"]),
        .library(name: "SwiftWebCore", targets: ["SwiftWebCore"]),
        .executable(name: "swiftweb", targets: ["SwiftWebGenerator"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.59.0"),
        .package(url: "https://github.com/vapor/postgres-nio.git", from: "1.21.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        .target(name: "SwiftView", dependencies: [
            "SwiftWebCore"
        ]),
        .target(name: "SwiftDB", dependencies: [
            .product(name: "NIO", package: "swift-nio"),
            .product(name: "PostgresNIO", package: "postgres-nio"),
            "SwiftWebCore"
        ]),
        .target(name: "SwiftWeb", dependencies: [
            .product(name: "NIO", package: "swift-nio"),
            .product(name: "NIOHTTP1", package: "swift-nio"),
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
            "SwiftDB",
            "SwiftView",
            "SwiftWebCore"
        ],
        swiftSettings: [
            .define("SWIFTWEB_LOGGING_ENABLED")
        ]),
        .target(name: "SwiftWebCore", dependencies: [
            .product(name: "NIOHTTP1", package: "swift-nio"),
        ]),
        .executableTarget(
            name: "SwiftWebGenerator",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            resources: [
                .copy("Template")
            ]
        ),
        .testTarget(
            name: "SwiftWebTests",
            dependencies: ["SwiftWeb"]
        ),
        .testTarget(
            name: "SwiftDBTests",
            dependencies: [
                "SwiftDB",
                .product(name: "NIO", package: "swift-nio"),
            ]
        ),
        .testTarget(
            name: "SwiftViewTests",
            dependencies: ["SwiftView"]
        )
    ]
)

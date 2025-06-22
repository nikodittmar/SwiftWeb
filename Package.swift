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
        .executable(name: "SwiftWebCLI", targets: ["SwiftWebCLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.59.0"),
        .package(url: "https://github.com/vapor/postgres-nio.git", from: "1.21.0"),
    ],
    targets: [
        .target(name: "SwiftDB", dependencies: [
            .product(name: "PostgresNIO", package: "postgres-nio"),
        ]),
        .target(name: "SwiftWeb", dependencies: [
            .product(name: "NIO", package: "swift-nio"),
            .product(name: "NIOHTTP1", package: "swift-nio"),
            "SwiftDB"
        ]),
        .executableTarget(
            name: "SwiftWebCLI",
            dependencies: [
                "SwiftWeb"
            ]
        ),
        .testTarget(
            name: "SwiftWebTests",
            dependencies: [
                "SwiftWeb"
            ]
        ),
        .testTarget(
            name: "SwiftDBTests",
            dependencies: [
                "SwiftDB"
            ]
        )
    ]
)

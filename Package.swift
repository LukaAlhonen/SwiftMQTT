// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftMQTT",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "SwiftMQTT", targets: ["SwiftMQTT"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.94.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SwiftMQTT",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio")
            ]
        ),
        .testTarget(name: "SwiftMQTTTests", dependencies: [.target(name: "SwiftMQTT")]),
    ]
)

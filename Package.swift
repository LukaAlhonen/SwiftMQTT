// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftMQTT",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "SwiftMQTT", targets: ["SwiftMQTT"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log", from: "1.6.0"),
        .package(url: "https://github.com/apple/swift-nio-transport-services.git", from: "1.13.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SwiftMQTT",
            dependencies: [.product(name: "NIOTransportServices", package: "swift-nio-transport-services")]
        ),
        .executableTarget(
            name: "SwiftMQTTCli",
            dependencies: [.product(name: "Logging", package: "swift-log"), .target(name: "SwiftMQTT")],
        ),
        .testTarget(name: "SwiftMQTTTests", dependencies: [.target(name: "SwiftMQTT")])
    ]
)

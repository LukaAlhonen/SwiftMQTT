// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftMQTT",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log", from: "1.6.0"),
        .package(url: "https://github.com/apple/swift-nio-transport-services.git", from: "1.13.0"),
        // .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", from: "0.63.2")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "SwiftMQTT",
            dependencies: [.product(name: "Logging", package: "swift-log"), .product(name: "NIOTransportServices", package: "swift-nio-transport-services")],
            // plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .testTarget(name: "SwiftMQTTTests", dependencies: [.target(name: "SwiftMQTT")])
    ]
)

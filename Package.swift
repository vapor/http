// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "http-kit",
    products: [
        .library(name: "HTTPKit", targets: ["HTTPKit"]),
    ],
    dependencies: [
        // Event-driven network application framework for high performance protocol servers & clients, non-blocking.
        .package(url: "https://github.com/apple/swift-nio.git", .branch("master")),
        
        // Bindings to OpenSSL-compatible libraries for TLS support in SwiftNIO
        .package(url: "https://github.com/tanner0101/swift-nio-ssl.git", .branch("master")),
    ],
    targets: [
        .target(name: "HTTPKit", dependencies: [
            "NIO",
            "NIOFoundationCompat",
            "NIOHTTP1",
            "NIOOpenSSL",
            "NIOWebSocket"
        ]),
        .target(name: "HTTPKitExample", dependencies: ["HTTPKit"]),
        .testTarget(name: "HTTPKitTests", dependencies: ["HTTPKit"]),
    ]
)

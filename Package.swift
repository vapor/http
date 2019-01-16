// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "engine",
    products: [
        .library(name: "HTTP", targets: ["HTTP"]),
        .library(name: "WebSocket", targets: ["WebSocket"]),
    ],
    dependencies: [
        // Event-driven network application framework for high performance protocol servers & clients, non-blocking.
        .package(url: "https://github.com/apple/swift-nio.git", .branch("master")),

        // Bindings to OpenSSL-compatible libraries for TLS support in SwiftNIO
        .package(url: "https://github.com/tanner0101/swift-nio-ssl.git", .branch("master")),
    ],
    targets: [
        .target(name: "HTTP", dependencies: ["NIO", "NIOFoundationCompat", "NIOHTTP1", "NIOOpenSSL"]),
        .testTarget(name: "HTTPTests", dependencies: ["HTTP"]),
        .target(name: "HTTPPerformance", dependencies: ["HTTP"]),
        .target(name: "WebSocket", dependencies: ["HTTP", "NIO", "NIOWebSocket"]),
        .target(name: "WebSocketDevelopment", dependencies: ["WebSocket"]),
        .testTarget(name: "WebSocketTests", dependencies: ["WebSocket"]),
    ]
)

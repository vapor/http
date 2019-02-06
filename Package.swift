// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "HTTP",
    products: [
        .library(name: "HTTP", targets: ["HTTP"]),
    ],
    dependencies: [
        // 🌎 Utility package containing tools for byte manipulation, Codable, OS APIs, and debugging.
        .package(url: "https://github.com/vapor/core.git", from: "3.0.0"),
        
        // Event-driven network application framework for high performance protocol servers & clients, non-blocking.
        .package(url: "https://github.com/apple/swift-nio.git", from: "1.13.0"),

        // Bindings to OpenSSL-compatible libraries for TLS support in SwiftNIO
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "1.0.1"),
    ],
    targets: [
        .target(name: "HTTP", dependencies: ["Async", "Bits", "Core", "Debugging", "NIO", "NIOOpenSSL", "NIOHTTP1"]),
        .testTarget(name: "HTTPTests", dependencies: ["HTTP"]),
        .target(name: "HTTPPerformance", dependencies: ["HTTP"]),
    ]
)

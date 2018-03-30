// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "Engine",
    products: [
        .library(name: "FormURLEncoded", targets: ["FormURLEncoded"]),
        .library(name: "HTTP", targets: ["HTTP"]),
        .library(name: "Multipart", targets: ["Multipart"]),
        .library(name: "WebSocket", targets: ["WebSocket"]),
    ],
    dependencies: [
        // 🌎 Utility package containing tools for byte manipulation, Codable, OS APIs, and debugging.
        .package(url: "https://github.com/vapor/core.git", from: "3.0.0-rc.2"),
        
        // Event-driven network application framework for high performance protocol servers & clients, non-blocking.
        .package(url: "https://github.com/apple/swift-nio.git", from: "1.2.0"),
    ],
    targets: [
        .target(name: "FormURLEncoded", dependencies: ["Bits", "Core", "HTTP", "Debugging"]),
        .testTarget(name: "FormURLEncodedTests", dependencies: ["FormURLEncoded"]),
        .target(name: "HTTP", dependencies: ["Async", "Bits", "Core", "Debugging", "NIO", "NIOHTTP1"]),
        .testTarget(name: "HTTPTests", dependencies: ["HTTP"]),
        .target(name: "Performance", dependencies: ["HTTP"]),
        .target(name: "Multipart", dependencies: ["Debugging", "HTTP"]),
        .testTarget(name: "MultipartTests", dependencies: ["Multipart"]),
        .target(name: "WebSocket", dependencies: ["Debugging", "HTTP", "NIO", "NIOWebSocket"]),
        .testTarget(name: "WebSocketTests", dependencies: ["WebSocket"]),
    ]
)

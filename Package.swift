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
        .package(url: "https://github.com/apple/swift-nio-ssl.git", .branch("master")),
        
        // HTTP/2 support for SwiftNIO
        .package(url: "https://github.com/apple/swift-nio-http2.git", .branch("master")),
        
        // Swift logging API
        // .package(url: "https://github.com/weissi/swift-server-logging-api-proposal", .branch("master")),
    ],
    targets: [
        .target(name: "HTTPKit", dependencies: [
            // "Logging", 
            "NIO",
            "NIOFoundationCompat",
            "NIOHTTP1",
            "NIOHTTP2",
            "NIOOpenSSL",
            "NIOWebSocket"
        ]),
        .target(name: "HTTPKitExample", dependencies: ["HTTPKit"]),
        .testTarget(name: "HTTPKitTests", dependencies: ["HTTPKit"]),
    ]
)

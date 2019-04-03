// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "http-kit",
    products: [
        .library(name: "HTTPKit", targets: ["HTTPKit"]),
    ],
    dependencies: [
        // Event-driven network application framework for high performance protocol servers & clients, non-blocking.
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
        
        // Bindings to OpenSSL-compatible libraries for TLS support in SwiftNIO
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.0.0"),
        
        // HTTP/2 support for SwiftNIO
        .package(url: "https://github.com/apple/swift-nio-http2.git", from: "1.0.0"),
        
        // Useful code around SwiftNIO.
        .package(url: "https://github.com/apple/swift-nio-extras.git", from: "1.0.0"),
        
        // Swift logging API
        .package(url: "https://github.com/apple/swift-log.git", .branch("master")),
    ],
    targets: [
        .target(name: "CMultipartParser"),
        .target(name: "HTTPKit", dependencies: [
            "CMultipartParser",
            "Logging",
            "NIO",
            "NIOExtras",
            "NIOFoundationCompat",
            "NIOHTTPCompression",
            "NIOHTTP1",
            "NIOHTTP2",
            "NIOSSL",
            "NIOWebSocket"
        ]),
        .target(name: "HTTPKitExample", dependencies: ["HTTPKit"]),
        .testTarget(name: "HTTPKitTests", dependencies: ["HTTPKit"]),
    ]
)

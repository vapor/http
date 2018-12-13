// swift-tools-version:4.2
import PackageDescription

let package = Package(
    name: "http",
    products: [
        .library(name: "HTTP", targets: ["HTTP"]),
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
    ]
)

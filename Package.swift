// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "Engine",
    products: [
        .library(name: "FormURLEncoded", targets: ["FormURLEncoded"]),
        .library(name: "HTTP", targets: ["HTTP"]),
        // .library(name: "HTTP2", targets: ["HTTP2"]),
        .library(name: "Multipart", targets: ["Multipart"]),
        .library(name: "Routing", targets: ["Routing"]),
        .library(name: "WebSocket", targets: ["WebSocket"]),
    ],
    dependencies: [
        // Core extensions, type-aliases, and functions that facilitate common tasks.
        .package(url: "https://github.com/vapor/core.git", .exact("3.0.0-beta.1")),

        // Core extensions, type-aliases, and functions that facilitate common tasks.
        .package(url: "https://github.com/vapor/crypto.git", .exact("3.0.0-beta.1")),

        // Core extensions, type-aliases, and functions that facilitate common tasks.
        .package(url: "https://github.com/vapor/service.git", .exact("1.0.0-beta.1")),

        // Pure Swift (POSIX) TCP and UDP non-blocking socket layer, with event-driven Server and Client.
        .package(url: "https://github.com/vapor/sockets.git", .exact("3.0.0-beta.1")),

        // Swift OpenSSL & macOS Security TLS wrapper
        .package(url: "https://github.com/vapor/tls.git", .exact("3.0.0-beta.1")),
    ],
    targets: [
        .target(name: "CHTTP"),
        .target(name: "FormURLEncoded", dependencies: ["Bits", "HTTP", "Debugging"]),
        .testTarget(name: "FormURLEncodedTests", dependencies: ["FormURLEncoded"]),
        .target(name: "HTTP", dependencies: ["CHTTP", "TCP"]),
        .testTarget(name: "HTTPTests", dependencies: ["HTTP"]),
        .target(name: "Performance", dependencies: ["HTTP", "TCP"]),
        // .target(name: "HTTP2", dependencies: ["HTTP", "TLS", "Pufferfish"]),
        // .testTarget(name: "HTTP2Tests", dependencies: ["HTTP2"]),
        .target(name: "Multipart", dependencies: ["Debugging", "HTTP"]),
        .testTarget(name: "MultipartTests", dependencies: ["Multipart"]),
        .target(name: "Routing", dependencies: ["Debugging", "HTTP", "Service", "WebSocket"]),
        .testTarget(name: "RoutingTests", dependencies: ["Routing"]),
        .testTarget(name: "WebSocketTests", dependencies: ["WebSocket"]),
    ]
)

#if os(macOS)
    package.targets.append(.target(name: "WebSocket", dependencies: ["Debugging", "TCP", "AppleTLS", "HTTP", "Crypto"]))
#else
    package.targets.append(.target(name: "WebSocket", dependencies: ["Debugging", "TCP", "OpenSSL", "HTTP", "Crypto"]))
#endif

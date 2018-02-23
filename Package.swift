// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "Engine",
    products: [
        .library(name: "FormURLEncoded", targets: ["FormURLEncoded"]),
        .library(name: "HTTP", targets: ["HTTP"]),
        // .library(name: "HTTP2", targets: ["HTTP2"]),
        .library(name: "Multipart", targets: ["Multipart"]),
        .library(name: "WebSocket", targets: ["WebSocket"]),
    ],
    dependencies: [
        // 🌎 Utility package containing tools for byte manipulation, Codable, OS APIs, and debugging.
        .package(url: "https://github.com/vapor/core.git", from: "3.0.0-rc"),

        // 🔑 Hashing (BCrypt, SHA, HMAC, etc), encryption, and randomness.
        .package(url: "https://github.com/vapor/crypto.git", from: "3.0.0-rc"),

        // 📦 Dependency injection / inversion of control framework.
        .package(url: "https://github.com/vapor/service.git", from: "1.0.0-rc"),

        // 🔌 Non-blocking TCP socket layer, with event-driven server and client.
        .package(url: "https://github.com/vapor/sockets.git", from: "3.0.0-rc"),

        // 🔒 Non-blocking, event-driven TLS built on OpenSSL & macOS security.
        .package(url: "https://github.com/vapor/tls.git", from: "3.0.0-rc"),
    ],
    targets: [
        .target(name: "CHTTP"),
        .target(name: "FormURLEncoded", dependencies: ["Bits", "HTTP", "Debugging"]),
        .testTarget(name: "FormURLEncodedTests", dependencies: ["FormURLEncoded"]),
        .target(name: "HTTP", dependencies: ["CHTTP", "TCP"]),
        .target(name: "Performance", dependencies: ["HTTP", "TCP"]),
        // .target(name: "HTTP2", dependencies: ["HTTP", "TLS", "Pufferfish"]),
        // .testTarget(name: "HTTP2Tests", dependencies: ["HTTP2"]),
        .target(name: "Multipart", dependencies: ["Debugging", "HTTP"]),
        .testTarget(name: "MultipartTests", dependencies: ["Multipart"]),
        .testTarget(name: "WebSocketTests", dependencies: ["WebSocket"]),
    ]
)

#if os(macOS)
package.targets.append(.target(name: "WebSocket", dependencies: ["Debugging", "TCP", "AppleTLS", "HTTP", "Crypto"]))
package.targets.append(.testTarget(name: "HTTPTests", dependencies: ["AppleTLS", "HTTP"]))
#else
package.targets.append(.target(name: "WebSocket", dependencies: ["Debugging", "TCP", "OpenSSL", "HTTP", "Crypto"]))
package.targets.append(.testTarget(name: "HTTPTests", dependencies: ["OpenSSL", "HTTP"]))
#endif

// swift-tools-version:4.0
import PackageDescription

#if os(macOS)
    let ssl: Target.Dependency = "AppleTLS"
#else
    let ssl: Target.Dependency = "OpenSSL"
#endif

let package = Package(
    name: "Engine",
    products: [
        .library(name: "FormURLEncoded", targets: ["FormURLEncoded"]),
        .library(name: "HTTP", targets: ["HTTP"]),
        // .library(name: "HTTP2", targets: ["HTTP2"]),
        .library(name: "Multipart", targets: ["Multipart"]),
        .library(name: "Routing", targets: ["Routing"]),
        .library(name: "ServerSecurity", targets: ["ServerSecurity"]),
        .library(name: "TCP", targets: ["TCP"]),
        .library(name: "TLS", targets: ["TLS"]),
        .library(name: "WebSocket", targets: ["WebSocket"]),
    ],
    dependencies: [
        // Swift Promises, Futures, and Streams.
        .package(url: "https://github.com/vapor/async.git", .branch("beta")),

        // Core extensions, type-aliases, and functions that facilitate common tasks.
        .package(url: "https://github.com/vapor/core.git", .branch("beta")),

        // Core extensions, type-aliases, and functions that facilitate common tasks.
        .package(url: "https://github.com/vapor/crypto.git", .branch("beta")),

        // Core extensions, type-aliases, and functions that facilitate common tasks.
        .package(url: "https://github.com/vapor/service.git", .branch("beta")),
    ],
    targets: [
        .target(name: "CHTTP"),
        .target(name: "FormURLEncoded", dependencies: ["Bits", "HTTP", "Debugging"]),
        .testTarget(name: "FormURLEncodedTests", dependencies: ["FormURLEncoded"]),
        .target(name: "HTTP", dependencies: ["CHTTP", "TCP"]),
        .testTarget(name: "HTTPTests", dependencies: ["HTTP"]),
        // .target(name: "HTTP2", dependencies: ["HTTP", "TLS", "Pufferfish"]),
        // .testTarget(name: "HTTP2Tests", dependencies: ["HTTP2"]),
        .target(name: "Multipart", dependencies: ["Debugging", "HTTP"]),
        .testTarget(name: "MultipartTests", dependencies: ["Multipart"]),
        .target(name: "Routing", dependencies: ["Debugging", "HTTP", "WebSocket"]),
        .testTarget(name: "RoutingTests", dependencies: ["Routing"]),
        .target(name: "ServerSecurity", dependencies: ["COperatingSystem", "TCP"]),
        .target(name: "TCP", dependencies: ["Async", "COperatingSystem", "Debugging", "Service"]),
        .testTarget(name: "TCPTests", dependencies: ["TCP"]),
        .target(name: "TLS", dependencies: ["Async", "Bits", "Debugging", "TCP"]),
        .testTarget(name: "TLSTests", dependencies: [ssl, "TLS"]),
        .target(name: "WebSocket", dependencies: ["Debugging", "TCP", "TLS", "HTTP", "Crypto"]),
        .testTarget(name: "WebSocketTests", dependencies: ["WebSocket"]),
    ]
)

#if os(macOS)
   package.targets.append(
        .target(name: "AppleTLS", dependencies: ["Async", "Bits", "Debugging", "TLS"])
    )

    package.products.append(
        .library(name: "AppleTLS", targets: ["AppleTLS"])
    )
#else
    package.dependencies.append(
        .package(url: "https://github.com/vapor/copenssl.git", .exact("1.0.0-alpha.1"))
    )
    
    package.targets.append(
        .target(name: "OpenSSL", dependencies: ["Async", "COpenSSL", "Debugging", "TLS"])
    )
#endif

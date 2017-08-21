// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "Engine",
    products: [
        .library(name: "TCP", targets: ["TCP"]),
        .library(name: "HTTP", targets: ["HTTP"]),
        .library(name: "WebSockets", targets: ["WebSockets"]),
    ],
    dependencies: [
        // Core extensions, type-aliases, and functions that facilitate common tasks.
        .package(url: "https://github.com/vapor/core.git", .revision("beta")),

        // A library to aid Vapor users with better debugging around the framework
        .package(url: "https://github.com/vapor/debugging.git", .revision("beta")),
        
        // Cryptographic functionality like hashes. Used for Websockets
        .package(url: "https://github.com/vapor/crypto.git", .revision("rework")),
    ],
    targets: [
        .target(name: "Performance", dependencies: ["HTTP", "TCP", "WebSockets"]),
        .target(name: "TCP", dependencies: ["Debugging", "Core", "libc"]),
        .testTarget(name: "TCPTests", dependencies: ["TCP"]),
        .target(name: "CHTTP"),
        .target(name: "HTTP", dependencies: ["CHTTP", "TCP"]),
        .testTarget(name: "HTTPTests", dependencies: ["HTTP"]),
        .target(name: "WebSockets", dependencies: ["HTTP", "Core", "Crypto"]),
        .testTarget(name: "WebSocketsTests", dependencies: ["WebSockets"]),
    ]
)

// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "Engine",
    products: [
        .library(name: "CHTTP", targets: ["CHTTP"]),
        .library(name: "URI", targets: ["URI"]),
        .library(name: "Cookies", targets: ["Cookies"]),
        .library(name: "HTTP", targets: ["HTTP"]),
        .library(name: "WebSockets", targets: ["WebSockets"]),
        .library(name: "SMTP", targets: ["SMTP"]),
    ],
    dependencies: [
        // Crypto
        .package(url: "https://github.com/vapor/crypto.git", .upToNextMajor(from: "2.1.0")),

        // Secure Sockets
        .package(url: "https://github.com/vapor/tls.git", .upToNextMajor(from: "2.1.0")),
        
        // Core Stuff
        .package(url: "https://github.com/vapor/core.git", .upToNextMajor(from: "2.1.1")),
        
        // Sockets
        .package(url: "https://github.com/vapor/sockets.git", .upToNextMajor(from: "2.1.0")),
        
        // Random
        .package(url: "https://github.com/vapor/random.git", .upToNextMajor(from: "1.2.0")),
        
        // Crypto
        .package(url: "https://github.com/vapor/crypto.git", .upToNextMajor(from: "2.1.0")),
    ],
    targets: [
        .target(name: "CHTTP"),
        .target(name: "URI", dependencies: ["CHTTP", "Core", "Transport"]),
        .testTarget(name: "URITests", dependencies: ["URI"]),
        .target(name: "Cookies", dependencies: ["HTTP"]),
        .testTarget(name: "CookiesTests", dependencies: ["Cookies"]),
        .target(name: "HTTP", dependencies: ["URI", "CHTTP", "Sockets", "TLS", "Random"]),
        .testTarget(name: "HTTPTests", dependencies: ["HTTP"]),
        .target(name: "WebSockets", dependencies: ["HTTP", "URI", "Crypto"]),
        .testTarget(name: "WebSocketsTests", dependencies: ["WebSockets"]),
        .target(name: "SMTP", dependencies: ["Sockets", "Transport"]),
        .testTarget(name: "SMTPTests", dependencies: ["SMTP"]),
        // Target(name: "Performance", dependencies: ["HTTP"])
    ]
)

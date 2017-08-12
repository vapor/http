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
        .package(url: "https://github.com/vapor/crypto.git", .branch("beta")),

        // Secure Sockets
        .package(url: "https://github.com/vapor/tls.git", .branch("beta")),
        
        // Core Stuff
        .package(url: "https://github.com/vapor/core.git", .branch("beta")),
        
        // Sockets
        .package(url: "https://github.com/vapor/sockets.git", .branch("beta")),
        
        // Random
        .package(url: "https://github.com/vapor/random.git", .branch("beta")),
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
        .target(name: "Performance", dependencies: ["HTTP"])
    ]
)

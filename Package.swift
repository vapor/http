// swift-tools-version:3.0
import PackageDescription

let package = Package(
    name: "Engine",
    targets: [
        Target(name: "CHTTP"),
        Target(name: "URI", dependencies: ["CHTTP"]),
        Target(name: "Cookies", dependencies: ["HTTP"]),
        Target(name: "HTTP", dependencies: ["URI", "CHTTP"]),
        Target(name: "WebSockets", dependencies: ["HTTP", "URI"]),
        Target(name: "SMTP")
        // Target(name: "Performance", dependencies: ["HTTP"])
    ],
    dependencies: [
    // Crypto
    .Package(url: "https://github.com/vapor/crypto.git", majorVersion: 2),

    // Secure Sockets
    .Package(url: "https://github.com/vapor/tls.git", majorVersion: 2),
    ],
    exclude: [
        "Sources/Performance"
    ]
)

// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "Engine",
    products: [
        .library(name: "Sockets", targets: ["Sockets"]),
        .library(name: "HTTP", targets: ["HTTP"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/core.git", .revision("rework"))
    ],
    targets: [
        .target(name: "Sockets", dependencies: ["libc", "Core"]),
        .testTarget(name: "SocketsTests", dependencies: ["Sockets"]),
        .target(name: "CHTTP"),
        .target(name: "HTTP", dependencies: ["CHTTP", "Sockets"]),
        .testTarget(name: "HTTPTests", dependencies: ["HTTP"]),
    ]
)

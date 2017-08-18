// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "Engine",
    products: [
        .library(name: "Async", targets: ["Async"]),
        .library(name: "Streams", targets: ["Streams"]),
        .library(name: "Sockets", targets: ["Sockets"]),
        .library(name: "HTTP", targets: ["HTTP"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/core.git", .revision("rework"))
    ],
    targets: [
        .target(name: "Async"),
        .target(name: "Streams", dependencies: ["libc"]),
        .testTarget(name: "StreamsTests", dependencies: ["Streams"]),
        .target(name: "Sockets", dependencies: ["Streams"]),
        .testTarget(name: "SocketsTests", dependencies: ["Sockets"]),
        .target(name: "CHTTP"),
        .target(name: "HTTP", dependencies: ["CHTTP", "Sockets"]),
        .testTarget(name: "HTTPTests", dependencies: ["HTTP"]),
    ]
)

// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "Engine",
    products: [
        .library(name: "Streams", targets: ["Streams"]),
        .library(name: "Sockets", targets: ["Sockets"]),
        .library(name: "HTTP", targets: ["HTTP"]),
    ],
    dependencies: [],
    targets: [
        .target(name: "Streams"),
        .testTarget(name: "StreamsTests", dependencies: ["Streams"]),
        .target(name: "Sockets", dependencies: ["Streams"]),
        .testTarget(name: "SocketsTests", dependencies: ["Sockets"]),
        .target(name: "HTTP", dependencies: ["Sockets"]),
        .testTarget(name: "HTTPTests", dependencies: ["HTTP"]),
    ]
)

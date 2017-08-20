// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "Engine",
    products: [
        .library(name: "TCP", targets: ["TCP"]),
        .library(name: "HTTP", targets: ["HTTP"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/core.git", .revision("inputoutput"))
    ],
    targets: [
        .target(name: "Development", dependencies: ["HTTP", "TCP"]),
        .target(name: "TCP", dependencies: ["libc", "Core"]),
        .testTarget(name: "TCPTests", dependencies: ["TCP"]),
        .target(name: "CHTTP"),
        .target(name: "HTTP", dependencies: ["CHTTP", "TCP"]),
        .testTarget(name: "HTTPTests", dependencies: ["HTTP"]),
    ]
)

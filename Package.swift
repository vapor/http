// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "HTTP",
    products: [
        .library(name: "HTTP", targets: ["HTTP"]),
    ],
    dependencies: [
        // 🌎 Utility package containing tools for byte manipulation, Codable, OS APIs, and debugging.
        .package(url: "https://github.com/vapor/core.git", from: "3.0.0"),
        
        // Event-driven network application framework for high performance protocol servers & clients, non-blocking.
        .package(url: "https://github.com/apple/swift-nio.git", from: "1.4.0"),
    ],
    targets: [
        .testTarget(name: "HTTPTests", dependencies: ["HTTP"]),
        .target(name: "HTTPPerformance", dependencies: ["HTTP"]),
    ]
)

var dependencies: [Target.Dependency] = ["Async", "Bits", "Core", "Debugging", "NIO", "NIOHTTP1"]

#if os(Linux)
// Bindings to OpenSSL-compatible libraries for TLS support in SwiftNIO
package.dependencies.append(.package(url: "https://github.com/apple/swift-nio-ssl.git", from: "1.0.1"))
dependencies.append("NIOOpenSSL")
#else
// Extensions for SwiftNIO to support Apple platforms as first-class citizens.
package.dependencies.append(.package(url: "https://github.com/apple/swift-nio-transport-services.git", from: "0.1.0"))
dependencies.append("NIOTransportServices")
#endif
package.targets.append(.target(name: "HTTP", dependencies: dependencies))

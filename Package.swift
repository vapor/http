import PackageDescription

let dependencies: [Package.Dependency] = [
    // Crypto
    .Package(url: "https://github.com/vapor/crypto.git", majorVersion: 0, minor: 2),

    // Secure Sockets
    .Package(url: "https://github.com/vapor/tls.git", majorVersion: 0, minor: 7),

    // CoreComponents
    .Package(url: "https://github.com/vapor/core.git", majorVersion: 0, minor: 4),
]

let package = Package(
    name: "Engine",
    targets: [
        Target(
            name: "URI"
        ),
        Target(
            name: "Transport"
        ),
        Target(
            name: "HTTP",
            dependencies: [
              "URI", "Transport"
            ]
        ),
        Target(
            name: "WebSockets",
            dependencies: [
                "HTTP", "URI", "Transport"
            ]
        ),
        Target(
            name: "SMTP",
            dependencies: [
                "Transport"
            ]
        ),
        Target(
            name: "HTTPExample",
            dependencies: [
                "HTTP"
            ]
        ),
        Target(
            name: "WebSocketsExample",
            dependencies: [
                "WebSockets", "HTTP", "Transport"
            ]
        ),
        Target(
            name: "SMTPExample",
            dependencies: [
                "SMTP", "Transport"
            ]
        )
    ],
    dependencies: dependencies,
    exclude: [
        "Resources"
    ]
)

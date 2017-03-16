import PackageDescription

let dependencies: [Package.Dependency] = [
    // Crypto
    .Package(url: "https://github.com/vapor/crypto.git", majorVersion: 1),

    // Secure Sockets
    .Package(url: "https://github.com/vapor/tls.git", majorVersion: 1),

    // CoreComponents
    .Package(url: "https://github.com/vapor/core.git", majorVersion: 1),
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
        )
        /*
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
        */
    ],
    dependencies: dependencies,
    exclude: [
        "Resources",
        "Sources/HTTPExample",
        "Sources/WebSocketsExample",
        "Sources/SMTPExample",
    ]
)

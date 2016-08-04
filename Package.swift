import PackageDescription

let dependencies: [Package.Dependency] = [
    //Websockets
    .Package(url: "https://github.com/CryptoKitten/SHA1.git", majorVersion: 0, minor: 10),

    //Sockets, used by the built in HTTP server
    .Package(url: "https://github.com/czechboy0/Socks.git", majorVersion: 0, minor: 10),

    //CoreComponents
    .Package(url: "https://github.com/vapor/core.git", majorVersion: 0, minor: 3),
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

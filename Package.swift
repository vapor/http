import PackageDescription

let dependencies: [Package.Dependency] = [
    //Websockets
    .Package(url: "https://github.com/CryptoKitten/SHA1.git", majorVersion: 0, minor: 10),

    //Sockets, used by the built in HTTP server
    .Package(url: "https://github.com/czechboy0/Socks.git", majorVersion: 0, minor: 10),

    //CoreComponents
    .Package(url: "https://github.com/qutheory/core.git", majorVersion: 0, minor: 3)
]

let package = Package(
    name: "Engine",
    targets: [
        Target(
            name: "HTTP"
        ),
        Target(
            name: "URI"
        ),
        Target(
            name: "WebSockets",
            dependencies: [
                "HTTP"
            ]
        ),
        Target(
            name: "SMTP",
            dependencies: [
                "HTTP"
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
                "WebSockets"
            ]
        ),
        Target(
            name: "SMTPExample",
            dependencies: [
                "HTTP", "SMTP"
            ]
        )
    ],
    dependencies: dependencies,
    exclude: [
        "Resources"
    ]
)

import PackageDescription

let dependencies: [Package.Dependency] = [
    //Websockets
    .Package(url: "https://github.com/CryptoKitten/SHA1.git", majorVersion: 0, minor: 9),

    //Sockets, used by the built in HTTP server
    .Package(url: "https://github.com/czechboy0/Socks.git", majorVersion: 0, minor: 9),

    //CoreComponents
    .Package(url: "https://github.com/qutheory/core.git", majorVersion: 0, minor: 2)
]

let package = Package(
    name: "Engine",
    targets: [
        Target(
            name: "Engine"
        ),
        Target(
            name: "WebSockets",
            dependencies: [
                .Target(name: "Engine")
            ]
        ),
        Target(
            name: "SMTP",
            dependencies: [
              .Target(name: "Engine")
            ]
        ),
        Target(
            name: "EngineExample",
            dependencies: [
                .Target(name: "Engine")
            ]
        ),
        Target(
            name: "WebSocketsExample",
            dependencies: [
                .Target(name: "WebSockets")
            ]
        ),
        Target(
            name: "SMTPExample",
            dependencies: [
                .Target(name: "Engine"),
                .Target(name: "SMTP")
            ]
        )
    ],
    dependencies: dependencies,
    exclude: [
        "Resources"
    ]
)

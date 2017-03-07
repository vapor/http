import PackageDescription

let dependencies: [Package.Dependency] = [
    // Crypto
    .Package(url: "https://github.com/vapor/crypto.git", Version(2,0,0, prereleaseIdentifiers: ["alpha"])),

    // Secure Sockets
    .Package(url: "https://github.com/vapor/tls.git", Version(2,0,0, prereleaseIdentifiers: ["alpha"])),
]

let package = Package(
    name: "Engine",
    targets: [
        Target(name: "URI"),
        Target(name: "Transport"),
        Target(name: "Cookies", dependencies: [
            "HTTP"
        ]),
        Target(name: "HTTP", dependencies: [
              "URI", "Transport"
        ]),
        Target(name: "WebSockets", dependencies: [
            "HTTP", "URI", "Transport"
        ]),
        Target(name: "SMTP", dependencies: [
            "Transport"
        ])
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

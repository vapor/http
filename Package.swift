import PackageDescription

let beta = Version(2,0,0, prereleaseIdentifiers: ["beta"])

let dependencies: [Package.Dependency] = [
    // Crypto
    .Package(url: "https://github.com/vapor/crypto.git", beta),

    // Secure Sockets
    .Package(url: "https://github.com/vapor/tls.git", beta),
]

let package = Package(
    name: "Engine",
    targets: [
        Target(name: "URI"),
        Target(name: "Cookies", dependencies: [
            "HTTP"
        ]),
        Target(name: "HTTP", dependencies: [
            "URI"
        ]),
        Target(name: "WebSockets", dependencies: [
            "HTTP", "URI"
        ]),
        Target(name: "SMTP")
    ],
    dependencies: dependencies,
    exclude: [
        "Resources",
        "Sources/HTTPExample",
        "Sources/WebSocketsExample",
        "Sources/SMTPExample",
    ]
)

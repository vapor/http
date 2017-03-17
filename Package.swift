import PackageDescription

let dependencies: [Package.Dependency] = [
    // Crypto
    .Package(url: "https://github.com/vapor/crypto.git", Version(2,0,0, prereleaseIdentifiers: ["alpha"])),

    // Secure Sockets
    .Package(url: "https://github.com/vapor/tls.git", Version(0,0,0))// Version(2,0,0, prereleaseIdentifiers: ["alpha"]))
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

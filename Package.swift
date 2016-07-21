import PackageDescription

var dependencies: [Package.Dependency] = [
    //Standards package. Contains protocols for cross-project compatability.
    .Package(url: "https://github.com/open-swift/S4.git", majorVersion: 0, minor: 10),

    //Websockets
    .Package(url: "https://github.com/CryptoKitten/SHA1.git", majorVersion: 0, minor: 8),

    //Sockets, used by the built in HTTP server
    .Package(url: "https://github.com/czechboy0/Socks.git", majorVersion: 0, minor: 8),

    // libc
    .Package(url: "https://github.com/qutheory/libc.git", majorVersion: 0, minor: 1)
]

#if os(Linux)
dependencies += [
  //Wrapper around pthreads
  .Package(url: "https://github.com/ketzusaka/Strand.git", majorVersion: 1, minor: 5),
]
#endif

let package = Package(
    name: "Engine",
    targets: [
        Target(
            name: "Base"
        ),
        Target(
            name: "Engine",
            dependencies: [
                .Target(name: "Base")
            ]
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

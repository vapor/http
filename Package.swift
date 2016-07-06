import PackageDescription

let package = Package(
    name: "Engine",
    dependencies: [
        //Standards package. Contains protocols for cross-project compatability.
        .Package(url: "https://github.com/open-swift/S4.git", majorVersion: 0, minor: 10),

        //Websockets
        .Package(url: "https://github.com/CryptoKitten/SHA1.git", majorVersion: 0, minor: 8),

        //Allows complex key path subscripts
        // .Package(url: "https://github.com/qutheory/path-indexable.git", majorVersion: 0, minor: 2),

        //Wrapper around pthreads
        .Package(url: "https://github.com/ketzusaka/Strand.git", majorVersion: 1, minor: 5),

        //Sockets, used by the built in HTTP server
        .Package(url: "https://github.com/czechboy0/Socks.git", majorVersion: 0, minor: 8),

        // libc
        .Package(url: "https://github.com/qutheory/libc.git", majorVersion: 0, minor: 1)
    ],
    exclude: [
        "XcodeProject",
        "Generator",
        "Development"
    ],
    targets: [
        Target(
            name: "Engine",
            dependencies: [
                .Target(name: "ToolBox")
            ]
        ),
        Target(
            name: "WebSockets",
            dependencies: [
                .Target(name: "Engine")
            ]
        ),
        Target(
            name: "Development",
            dependencies: [
                .Target(name: "Engine"),
                .Target(name: "WebSockets")
            ]
        ),
        Target(
            name: "ToolBox"
        ),
    ]
)

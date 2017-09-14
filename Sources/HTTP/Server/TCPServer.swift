import Sockets

public typealias TCPServer = BasicServer<TCPInternetSocket>

extension BasicServer where StreamType == TCPInternetSocket {
    /// Use this initializer to create
    /// a basic HTTP server that serves local host
    /// this is most commonly used behind a proxy
    /// such as nginx that is handling the
    /// tls handshake
    @available(*, deprecated, message: "Use init(scheme:, hostname: port:, maxRequestSize:, listenMax:) instead.")
    public convenience init(
        scheme: String = "http",
        hostname: String = "0.0.0.0",
        port: Port = 8080,
        listenMax: Int = 128
    ) throws {
        try self.init(scheme: scheme, hostname: hostname, port: port, maxRequestSize: Int.max, listenMax: listenMax)
    }
    
    /// Use this initializer to create
    /// a basic HTTP server that serves local host
    /// this is most commonly used behind a proxy
    /// such as nginx that is handling the
    /// tls handshake
    public convenience init(
        scheme: String = "http",
        hostname: String = "0.0.0.0",
        port: Port = 8080,
        maxRequestSize: Int,
        listenMax: Int = 128
        ) throws {
        let tcp = try StreamType(scheme: scheme, hostname: hostname, port: port)
        try self.init(tcp, maxRequestSize: maxRequestSize, listenMax: listenMax)
    }
}

import Sockets

public typealias TCPServer = BasicServer<TCPInternetSocket>

extension BasicServer where StreamType == TCPInternetSocket {
    /// Use this initializer to create
    /// a basic HTTP server that serves local host
    /// this is most commonly used behind a proxy
    /// such as nginx that is handling the
    /// tls handshake
    public convenience init(
        scheme: String = "http",
        hostname: String = "0.0.0.0",
        port: Port = 8080,
        listenMax: Int = 128
    ) throws {
        let tcp = try StreamType(scheme: scheme, hostname: hostname, port: port)
        try self.init(tcp, listenMax: listenMax)
    }
}

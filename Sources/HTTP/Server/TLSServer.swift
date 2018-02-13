import Sockets
import TLS

public typealias TLSServer = BasicServer<TLS.InternetSocket>

extension BasicServer where StreamType == TLS.InternetSocket {
    /// Use this initializer to create a TLS Server
    @available(*, deprecated, message: "Use init(scheme:, hostname: port:, maxRequestSize:, listenMax:, context:) instead.")
    public convenience init(
        scheme: String = "https",
        hostname: String = "0.0.0.0",
        port: Port = 443,
        listenMax: Int = 128,
        context: TLS.Context
    ) throws {
        try self.init(scheme: scheme, hostname: hostname, port: port, maxRequestSize: Int.max, listenMax: listenMax, context: context)
    }
    
    /// Use this initializer to create a TLS Server
    public convenience init(
        scheme: String = "https",
        hostname: String = "0.0.0.0",
        port: Port = 443,
        maxRequestSize: Int,
        listenMax: Int = 128,
        context: TLS.Context
        ) throws {
        let tcp = try TCPInternetSocket(scheme: scheme, hostname: hostname, port: port)
        let tls = StreamType(tcp, context)
        try self.init(tls, maxRequestSize: maxRequestSize, listenMax: listenMax)
    }
}

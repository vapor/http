import Foundation

/// Engine server config struct.
///
///     let serverConfig = HTTPServerConfig.default(port: 8123)
///     services.register(serverConfig)
///
public struct HTTPServerConfig {
    /// Host name the server will bind to.
    public var hostname: String
    
    /// Port the server will bind to.
    public var port: Int
    
    /// Listen backlog.
    public var backlog: Int
    
    /// Number of client accepting workers.
    /// Should be equal to the number of logical cores.
    public var workerCount: Int
    
    /// Requests containing bodies larger than this maximum will be rejected, closing the connection.
    public var maxBodySize: Int
    
    /// When `true`, can prevent errors re-binding to a socket after successive server restarts.
    public var reuseAddress: Bool
    
    /// When `true`, OS will attempt to minimize TCP packet delay.
    public var tcpNoDelay: Bool
    
    /// Number of webSocket maxFrameSize.
    public var webSocketMaxFrameSize: Int
    
    /// When `true`, HTTP server will support gzip and deflate compression.
    public var supportCompression: Bool
    
    /// When `true`, HTTP server will support pipelined requests.
    public var supportPipelining: Bool
    
    public var supportHTTP2: Bool
    
    public var tlsConfig: TLSConfiguration?
    
    /// If set, this name will be serialized as the `Server` header in outgoing responses.
    public var serverName: String?
    
    /// An array of `HTTPProtocolUpgrader` to check for with each request.
    public var upgraders: [HTTPProtocolUpgrader]
    
    /// Any uncaught server or responder errors will go here.
    public var errorHandler: (Error) -> ()
    
    /// Creates a new `HTTPServerConfig`.
    ///
    /// - parameters:
    ///     - hostname: Socket hostname to bind to. Usually `localhost` or `::1`.
    ///     - port: Socket port to bind to. Usually `8080` for development and `80` for production.
    ///     - backlog: OS socket backlog size.
    ///     - workerCount: Number of `Worker`s to use for responding to incoming requests.
    ///                    This should be (and is by default) equal to the number of logical cores.
    ///     - maxBodySize: Requests with bodies larger than this maximum will be rejected.
    ///                    Streaming bodies, like chunked bodies, ignore this maximum.
    ///     - reuseAddress: When `true`, can prevent errors re-binding to a socket after successive server restarts.
    ///     - tcpNoDelay: When `true`, OS will attempt to minimize TCP packet delay.
    ///     - webSocketMaxFrameSize: Number of webSocket maxFrameSize.
    ///     - supportCompression: When `true`, HTTP server will support gzip and deflate compression.
    ///     - supportPipelining: When `true`, HTTP server will support pipelined requests.
    ///     - serverName: If set, this name will be serialized as the `Server` header in outgoing responses.
    ///     - upgraders: An array of `HTTPProtocolUpgrader` to check for with each request.
    ///     - errorHandler: Any uncaught server or responder errors will go here.
    public init(
        hostname: String = "127.0.0.1",
        port: Int = 8080,
        backlog: Int = 256,
        workerCount: Int = ProcessInfo.processInfo.activeProcessorCount,
        maxBodySize: Int = 1_000_000,
        reuseAddress: Bool = true,
        tcpNoDelay: Bool = true,
        webSocketMaxFrameSize: Int = 1 << 14,
        supportCompression: Bool = false,
        supportPipelining: Bool = false,
        supportHTTP2: Bool = false,
        tlsConfig: TLSConfiguration? = nil,
        serverName: String? = nil,
        upgraders: [HTTPProtocolUpgrader] = [],
        errorHandler: @escaping (Error) -> () = { _ in }
    ) {
        self.hostname = hostname
        self.port = port
        self.backlog = backlog
        self.workerCount = workerCount
        self.maxBodySize = maxBodySize
        self.reuseAddress = reuseAddress
        self.tcpNoDelay = tcpNoDelay
        self.webSocketMaxFrameSize = webSocketMaxFrameSize
        self.supportCompression = supportCompression
        self.supportPipelining = supportPipelining
        self.supportHTTP2 = supportHTTP2
        self.tlsConfig = tlsConfig
        self.serverName = serverName
        self.upgraders = upgraders
        self.errorHandler = errorHandler
    }
}

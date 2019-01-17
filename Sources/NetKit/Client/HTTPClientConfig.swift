/// Configuration options for `HTTPClient`.
public struct HTTPClientConfig {
    
    public var hostname: String
    public var port: Int
    public var tlsConfig: TLSConfiguration?
    
    /// The timeout that will apply to the connection attempt.
    public var connectTimeout: TimeAmount
    
    
    public var eventLoopGroup: EventLoopGroup
    
    /// Optional closure, which fires when a networking error is caught.
    public var errorHandler: (Error) -> ()
    
    /// Creates a new `HTTPClientConfig`.
    ///
    /// - parameters:
    ///     - scheme: Transport layer security to use, either tls or plainText.
    ///     - hostname: Remote server's hostname.
    ///     - port: Remote server's port, defaults to 80 for TCP and 443 for TLS.
    ///     - connectTimeout: The timeout that will apply to the connection attempt.
    ///     - worker: `Worker` to perform async work on.
    ///     - errorHandler: Optional closure, which fires when a networking error is caught.
    public init(
        hostname: String,
        port: Int? = nil,
        tlsConfig: TLSConfiguration? = nil,
        connectTimeout: TimeAmount = TimeAmount.seconds(10),
        on eventLoopGroup: EventLoopGroup,
        errorHandler: @escaping (Error) -> () = { _ in }
    ) {
        self.hostname = hostname
        self.port = port ?? (tlsConfig != nil ? 443 : 80)
        self.tlsConfig = tlsConfig
        self.connectTimeout = connectTimeout
        self.eventLoopGroup = eventLoopGroup
        self.errorHandler = errorHandler
    }
}

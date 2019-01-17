/// Configuration options for `HTTPClient`.
public struct HTTPClientConfig {
    /// The timeout that will apply to the connection attempt.
    public var connectTimeout: TimeAmount
    
    public var tlsConfig: TLSConfiguration?
    
    enum Worker {
        case unowned(EventLoop)
        case owned(MultiThreadedEventLoopGroup)
        
        var eventLoop: EventLoop {
            switch self {
            case .unowned(let eventLoop): return eventLoop
            case .owned(let group): return group.next()
            }
        }
    }
    
    var worker: Worker
    
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
        connectTimeout: TimeAmount = TimeAmount.seconds(10),
        tlsConfig: TLSConfiguration? = nil,
        eventLoop: EventLoop? = nil,
        errorHandler: @escaping (Error) -> () = { _ in }
    ) {
        self.connectTimeout = connectTimeout
        self.tlsConfig = tlsConfig
        if let eventLoop = eventLoop {
            self.worker = .unowned(eventLoop)
        } else {
            self.worker = .owned(MultiThreadedEventLoopGroup(numberOfThreads: 1))
        }
        self.errorHandler = errorHandler
    }
}

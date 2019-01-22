/// Configuration options for `HTTPClient`.
public struct HTTPClientConfig {
    public var tlsConfig: TLSConfiguration
    
    /// The timeout that will apply to the connection attempt.
    public var connectTimeout: TimeAmount
    
    public var proxy: HTTPClientProxy
    
    public var eventLoopGroup: EventLoopGroup
    
    /// Optional closure, which fires when a networking error is caught.
    public var errorHandler: (Error) -> ()
    
    /// Creates a new `HTTPClientConfig`.
    ///
    public init(
        tlsConfig: TLSConfiguration = .forClient(),
        connectTimeout: TimeAmount = TimeAmount.seconds(10),
        proxy: HTTPClientProxy = .none,
        on eventLoopGroup: EventLoopGroup,
        errorHandler: @escaping (Error) -> () = { _ in }
    ) {
        self.tlsConfig = tlsConfig
        self.connectTimeout = connectTimeout
        self.proxy = proxy
        self.eventLoopGroup = eventLoopGroup
        self.errorHandler = errorHandler
    }
}

public struct HTTPClientProxy {
    public static var none: HTTPClientProxy {
        return .init(storage: .none)
    }
    
    public static func server(hostname: String, port: Int) -> HTTPClientProxy {
        return .init(storage: .server(hostname: hostname, port: port))
    }
    
    enum Storage {
        case none
        case server(hostname: String, port: Int)
    }
    
    var storage: Storage
}

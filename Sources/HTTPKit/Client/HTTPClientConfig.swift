/// Configuration options for `HTTPClient`.
public struct HTTPClientConfig {
    public var tlsConfig: TLSConfiguration?
    
    /// The timeout that will apply to the connection attempt.
    public var connectTimeout: TimeAmount
    
    public var proxy: HTTPClientProxy
    
    /// Optional closure, which fires when a networking error is caught.
    public var errorHandler: (Error) -> ()
    
    /// Creates a new `HTTPClientConfig`.
    ///
    public init(
        tlsConfig: TLSConfiguration? = nil,
        connectTimeout: TimeAmount = TimeAmount.seconds(10),
        proxy: HTTPClientProxy = .none,
        errorHandler: @escaping (Error) -> () = { _ in }
    ) {
        self.tlsConfig = tlsConfig
        self.connectTimeout = connectTimeout
        self.proxy = proxy
        self.errorHandler = errorHandler
    }
}

public struct HTTPClientProxy {
    public static var none: HTTPClientProxy {
        return .init(storage: .none)
    }
    
    public static func server(url: URLRepresentable) -> HTTPClientProxy? {
        guard let url = url.convertToURL() else {
            return nil
        }
        guard let hostname = url.host else {
            return nil
        }
        return .server(hostname: hostname, port: url.port ?? 80)
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

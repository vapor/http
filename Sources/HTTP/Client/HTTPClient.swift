public final class HTTPClient {
    public let config: HTTPClientConfig
    
    public init(config: HTTPClientConfig = .init()) {
        self.config = config
    }
    
    public func get(_ url: URLRepresentable, headers: HTTPHeaders = [:]) -> EventLoopFuture<HTTPResponse> {
        return self.send(.init(method: .GET, url: url, headers: headers))
    }
    
    public func send(_ req: HTTPRequest) -> EventLoopFuture<HTTPResponse> {
        guard let hostname = req.url.host else {
            fatalError()
        }
        let scheme = req.url.scheme ?? "http"
        let port: Int
        let tlsConfig: TLSConfiguration?
        switch scheme {
        case "https":
            port = req.url.port ?? 443
            tlsConfig = config.tlsConfig ?? .forClient()
        default:
            port = req.url.port ?? 80
            tlsConfig = nil
        }
        return HTTPConnectedClient.connect(
            hostname: hostname,
            port: port,
            tlsConfig: tlsConfig,
            config: self.config
        ).then { client in
            return client.send(req)
        }
    }
    
    deinit {
        switch self.config.worker {
        case .owned(let group):
            group.shutdownGracefully { error in
                if let error = error {
                    ERROR("HTTPClient EventLoopGroup shutdown failed: \(error)")
                }
            }
        default: break
        }
    }
}

import Foundation

public final class HTTPClient {
    public let config: HTTPClientConfig
    
    public init(config: HTTPClientConfig) {
        self.config = config
    }
    
    public func get(_ url: URLRepresentable) -> EventLoopFuture<HTTPResponse> {
        return self.send(.init(method: .GET, url: url))
    }
    
    public func send(_ req: HTTPRequest) -> EventLoopFuture<HTTPResponse> {
        let hostname = req.url.host ?? ""
        let port = req.url.port ?? (req.url.scheme == "https" ? 443 : 80)
        return HTTPClientConnection.connect(
            hostname: hostname,
            port: port,
            tlsConfig: req.url.scheme == "https" ? self.config.tlsConfig : nil,
            proxy: self.config.proxy,
            connectTimeout: self.config.connectTimeout,
            on: self.config.eventLoopGroup.next(),
            errorHandler: self.config.errorHandler
        ).flatMap { client in
            return client.send(req).flatMap { res in
                if req.upgrader != nil {
                    #warning("TODO: check if actually upgraded here before not closing")
                    return client.channel.eventLoop.makeSucceededFuture(result: res)
                } else {
                    return client.close().map { res }
                }
            }
        }
    }
}

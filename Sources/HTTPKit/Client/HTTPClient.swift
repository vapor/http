import Foundation

public final class HTTPClient {
    public let config: HTTPClientConfig
    
    public let eventLoopGroup: EventLoopGroup
    
    public init(config: HTTPClientConfig = .init(), on eventLoopGroup: EventLoopGroup) {
        self.config = config
        self.eventLoopGroup = eventLoopGroup
    }
    
    public func get(_ url: URLRepresentable) -> EventLoopFuture<HTTPResponse> {
        return self.send(.init(method: .GET, url: url))
    }
    
    public func send(_ req: HTTPRequest) -> EventLoopFuture<HTTPResponse> {
        let hostname = req.url.host ?? ""
        let port = req.url.port ?? (req.url.scheme == "https" ? 443 : 80)
        let tlsConfig: TLSConfiguration?
        switch req.url.scheme {
        case "https":
            tlsConfig = self.config.tlsConfig ?? .forClient()
        default:
            tlsConfig = nil
        }
        return HTTPClientConnection.connect(
            hostname: hostname,
            port: port,
            tlsConfig: tlsConfig,
            proxy: self.config.proxy,
            connectTimeout: self.config.connectTimeout,
            on: self.eventLoopGroup.next(),
            errorHandler: self.config.errorHandler
        ).flatMap { client in
            return client.send(req).flatMap { res in
                if req.upgrader != nil {
                    // upgrader is responsible for closing
                    return client.channel.eventLoop.makeSucceededFuture(res)
                } else {
                    return client.close().map { res }
                }
            }
        }
    }
}

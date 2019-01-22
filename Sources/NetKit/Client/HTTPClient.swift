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
                return client.close().map { res }
            }
        }
    }
}

final class HTTPClientProxyConnectHandler: ChannelDuplexHandler {
    typealias InboundIn = HTTPClientResponsePart
    typealias OutboundIn = HTTPClientRequestPart
    typealias OutboundOut = HTTPClientRequestPart
    
    let hostname: String
    let port: Int
    var onConnect: (ChannelHandlerContext) -> EventLoopFuture<Void>
    
    private var buffer: [HTTPClientRequestPart]
    
    
    init(hostname: String, port: Int, onConnect: @escaping (ChannelHandlerContext) -> EventLoopFuture<Void>) {
        self.hostname = hostname
        self.port = port
        self.onConnect = onConnect
        self.buffer = []
    }
    
    func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
        let res = self.unwrapInboundIn(data)
        switch res {
        case .head(let head):
            assert(head.status == .ok)
        case .end:
            self.configureTLS(ctx: ctx)
        default: assertionFailure("invalid state: \(res)")
        }
    }
    
    func write(ctx: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let req = self.unwrapOutboundIn(data)
        self.buffer.append(req)
        promise?.succeed(result: ())
    }
    
    func channelActive(ctx: ChannelHandlerContext) {
        self.sendConnect(ctx: ctx)
    }
    
    // MARK: Private
    
    private func configureTLS(ctx: ChannelHandlerContext) {
        _ = self.onConnect(ctx).map {
            self.buffer.forEach { ctx.write(self.wrapOutboundOut($0), promise: nil) }
            ctx.flush()
            _ = ctx.pipeline.remove(handler: self)
        }
    }
    
    private func sendConnect(ctx: ChannelHandlerContext) {
        var head = HTTPRequestHead(
            version: .init(major: 1, minor: 1),
            method: .CONNECT,
            uri: "\(self.hostname):\(self.port)"
        )
        head.headers.add(name: "proxy-connection", value: "keep-alive")
        ctx.write(self.wrapOutboundOut(.head(head)), promise: nil)
        ctx.write(self.wrapOutboundOut(.end(nil)), promise: nil)
        ctx.flush()
    }
}

/// Connects to remote HTTP servers allowing you to send `HTTPRequest`s and
/// receive `HTTPResponse`s.
///
///     let httpRes = HTTPClient.connect(hostname: "vapor.codes", on: ...).map(to: HTTPResponse.self) { client in
///         return client.send(...)
///     }
///
public final class HTTPClientConnection {
    // MARK: Static

    /// Creates a new `HTTPClient` connected over TCP or TLS.
    ///
    ///     let httpRes = HTTPClient.connect(config: .init(hostname: "vapor.codes")).then { client in
    ///         return client.send(...)
    ///     }
    ///
    /// - parameters:
    ///     - config: Specifies client connection options such as hostname, port, and more.
    /// - returns: A `Future` containing the connected `HTTPClient`.
    public static func connect(
        hostname: String,
        port: Int? = nil,
        tlsConfig: TLSConfiguration? = nil,
        proxy: HTTPClientProxy = .none,
        connectTimeout: TimeAmount = TimeAmount.seconds(10),
        on eventLoop: EventLoopGroup,
        errorHandler: @escaping (Error) -> () = { _ in }
    ) -> EventLoopFuture<HTTPClientConnection> {
        let bootstrap = ClientBootstrap(group: eventLoop)
            .connectTimeout(connectTimeout)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelInitializer { channel in
                var handlers: [ChannelHandler] = []
                var otherHTTPHandlers: [ChannelHandler] = []
                
                switch proxy.storage {
                case .none:
                    if let tlsConfig = tlsConfig {
                        #warning("TODO: fix force try")
                        let sslContext = try! SSLContext(configuration: tlsConfig)
                        let tlsHandler = try! OpenSSLClientHandler(context: sslContext)
                        handlers.append(tlsHandler)
                    }
                case .server:
                    // tls will be set up after connect
                    break
                }

                
                let httpReqEncoder = HTTPRequestEncoder()
                handlers.append(httpReqEncoder)
                otherHTTPHandlers.append(httpReqEncoder)
                
                let httpResDecoder = HTTPResponseDecoder()
                handlers.append(httpResDecoder)
                otherHTTPHandlers.append(httpResDecoder)
                
                switch proxy.storage {
                case .none: break
                case .server:
                    let proxy = HTTPClientProxyConnectHandler(hostname: hostname, port: port ?? 443) { ctx in
                        return ctx.pipeline.remove(handler: httpResDecoder).flatMap { _ in
                            return ctx.pipeline.add(handler: HTTPResponseDecoder(), after: httpReqEncoder)
                        }.flatMap {
                            if let tlsConfig = tlsConfig {
                                let sslContext = try! SSLContext(configuration: tlsConfig)
                                let tlsHandler = try! OpenSSLClientHandler(context: sslContext)
                                return ctx.pipeline.add(handler: tlsHandler, first: true)
                            } else {
                                return ctx.eventLoop.makeSucceededFuture(result: ())
                            }
                        }
                    }
                    handlers.append(proxy)
                }
                    
                let clientResDecoder = HTTPClientResponseDecoder()
                handlers.append(clientResDecoder)
                otherHTTPHandlers.append(clientResDecoder)
                
                let clientReqEncoder = HTTPClientRequestEncoder(hostname: hostname)
                handlers.append(clientReqEncoder)
                otherHTTPHandlers.append(clientReqEncoder)
                
                let handler = HTTPClientHandler()
                otherHTTPHandlers.append(handler)
                
                let upgrader = HTTPClientUpgradeHandler(otherHTTPHandlers: otherHTTPHandlers)
                handlers.append(upgrader)
                handlers.append(handler)
                return channel.pipeline.addHandlers(handlers, first: false)
            }
        let connectHostname: String
        let connectPort: Int
        switch proxy.storage {
        case .none:
            connectHostname = hostname
            connectPort = port ?? (tlsConfig != nil ? 443 : 80)
        case .server(let hostname, let port):
            connectHostname = hostname
            connectPort = port
        }
        return bootstrap.connect(
            host: connectHostname,
            port: connectPort
        ).map { channel in
            return HTTPClientConnection(channel: channel)
        }
    }

    // MARK: Properties

    /// Private NIO channel powering this client.
    public let channel: Channel

    /// A `Future` that will complete when this `HTTPClient` closes.
    public var onClose: EventLoopFuture<Void> {
        return channel.closeFuture
    }

    /// Private init for creating a new `HTTPClient`. Use the `connect` methods.
    private init(channel: Channel) {
        self.channel = channel
    }

    // MARK: Methods

    /// Sends an `HTTPRequest` to the connected, remote server.
    ///
    ///     let httpRes = HTTPClient.connect(hostname: "vapor.codes", on: req).map(to: HTTPResponse.self) { client in
    ///         return client.respond(to: ...)
    ///     }
    ///
    /// - parameters:
    ///     - request: `HTTPRequest` to send to the remote server.
    /// - returns: A `Future` `HTTPResponse` containing the server's response.
    public func send(_ req: HTTPRequest) -> EventLoopFuture<HTTPResponse> {
        let promise = self.channel.eventLoop.makePromise(of: HTTPResponse.self)
        let ctx = HTTPClientRequestContext(request: req, promise: promise)
        self.channel.write(ctx, promise: nil)
        return promise.futureResult
    }

    /// Closes this `HTTPClient`'s connection to the remote server.
    public func close() -> EventLoopFuture<Void> {
        return channel.close(mode: .all)
    }
}


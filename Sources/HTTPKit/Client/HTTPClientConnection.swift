/// Connects to remote HTTP servers allowing you to send `HTTPRequest`s and
/// receive `HTTPResponse`s.
///
///     let httpRes = HTTPClient.connect(hostname: "vapor.codes", on: ...).map(to: HTTPResponse.self) { client in
///         return client.send(...)
///     }
///
#warning("TODO: consider remaing to HTTPTransport / RoundTripper")
internal final class HTTPClientConnection {
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
    static func connect(
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
                var otherHTTPHandlers: [RemovableChannelHandler] = []
                
                switch proxy.storage {
                case .none:
                    if let tlsConfig = tlsConfig {
                        let sslContext = try! SSLContext(configuration: tlsConfig)
                        let tlsHandler = try! OpenSSLClientHandler(
                            context: sslContext,
                            serverHostname: hostname.isIPAddress() ? nil : hostname
                        )
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
                    let proxy = HTTPClientProxyHandler(hostname: hostname, port: port ?? 443) { context in
                        
                        // re-add HTTPDecoder since it may consider the connection to be closed
                        _ = context.pipeline.removeHandler(httpResDecoder)
                        _ = context.pipeline.addHandler(httpResDecoder, position: .after(httpReqEncoder))
                        

                        // if necessary, add TLS handlers
                        if let tlsConfig = tlsConfig {
                            let sslContext = try! SSLContext(configuration: tlsConfig)
                            let tlsHandler = try! OpenSSLClientHandler(
                                context: sslContext,
                                serverHostname: hostname.isIPAddress() ? nil : hostname
                            )
                            _ = context.pipeline.addHandler(tlsHandler, position: .first)
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
                return channel.pipeline.addHandlers(handlers, position: .last)
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
        let context = HTTPClientRequestContext(request: req, promise: promise)
        self.channel.write(context, promise: nil)
        return promise.futureResult
    }
    
    /// Closes this `HTTPClient`'s connection to the remote server.
    public func close() -> EventLoopFuture<Void> {
        return channel.close(mode: .all)
    }
}


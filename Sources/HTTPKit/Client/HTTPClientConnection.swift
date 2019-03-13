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
                var handlers: [(String, ChannelHandler)] = []
                var httpHandlerNames: [String] = []
                
                switch proxy.storage {
                case .none:
                    if let tlsConfig = tlsConfig {
                        let sslContext = try! NIOSSLContext(configuration: tlsConfig)
                        let tlsHandler = try! NIOSSLClientHandler(
                            context: sslContext,
                            serverHostname: hostname.isIPAddress() ? nil : hostname
                        )
                        handlers.append(("tls", tlsHandler))
                    }
                case .server:
                    // tls will be set up after connect
                    break
                }
                
                let httpReqEncoder = HTTPRequestEncoder()
                handlers.append(("http-encoder", httpReqEncoder))
                httpHandlerNames.append("http-encoder")
                
                let httpResDecoder = ByteToMessageHandler(HTTPResponseDecoder())
                handlers.append(("http-decoder", httpResDecoder))
                httpHandlerNames.append("http-decoder")
                
                switch proxy.storage {
                case .none: break
                case .server:
                    let proxy = HTTPClientProxyHandler(hostname: hostname, port: port ?? 443) { context in
                        
                        // re-add HTTPDecoder since it may consider the connection to be closed
                        _ = context.pipeline.removeHandler(name: "http-decoder")
                        _ = context.pipeline.addHandler(
                            ByteToMessageHandler(HTTPResponseDecoder()),
                            name: "http-decoder",
                            position: .after(httpReqEncoder)
                        )
                        
                        // if necessary, add TLS handlers
                        if let tlsConfig = tlsConfig {
                            let sslContext = try! NIOSSLContext(configuration: tlsConfig)
                            let tlsHandler = try! NIOSSLClientHandler(
                                context: sslContext,
                                serverHostname: hostname.isIPAddress() ? nil : hostname
                            )
                            _ = context.pipeline.addHandler(tlsHandler, position: .first)
                        }
                    }
                    handlers.append(("http-proxy", proxy))
                }
                
                let clientResDecoder = HTTPClientResponseDecoder()
                handlers.append(("client-decoder", clientResDecoder))
                httpHandlerNames.append("client-decoder")
                
                let clientReqEncoder = HTTPClientRequestEncoder(hostname: hostname)
                handlers.append(("client-encoder", clientReqEncoder))
                httpHandlerNames.append("client-encoder")
                
                let handler = HTTPClientHandler()
                httpHandlerNames.append("client")
                
                let upgrader = HTTPClientUpgradeHandler(httpHandlerNames: httpHandlerNames)
                handlers.append(("upgrader", upgrader))
                handlers.append(("client", handler))
                return .andAllSucceed(
                    handlers.map { channel.pipeline.addHandler($1, name: $0, position: .last) },
                    on: channel.eventLoop
                )
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


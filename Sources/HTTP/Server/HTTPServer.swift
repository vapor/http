import NIO
import NIOHTTP1

/// Simple HTTP server generic on an HTTP responder
/// that will be used to generate responses to incoming requests.
///
///     let server = try HTTPServer.start(hostname: hostname, port: port, responder: EchoResponder(), on: group).wait()
///     try server.onClose.wait()
///
public final class HTTPServer {
    /// MARK: Start
    
    /// Starts the server on the supplied hostname and port, using the supplied
    /// responder to generate HTTP responses for incoming requests.
    ///
    ///     let server = try HTTPServer.start(
    ///         config: .init(hostname: hostname, port: port),
    ///         delegate: EchoResponder()
    ///     ).wait()
    ///     try server.onClose.wait()
    ///
    /// - parameters:
    ///     - config: Specifies server start options such as hostname, port, and more.
    ///     - responder: Responds to incoming requests.
    public static func start<Delegate>(
        config: HTTPServerConfig,
        delegate: Delegate
    ) -> EventLoopFuture<HTTPServer> where Delegate: HTTPServerDelegate {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: config.workerCount)
        let bootstrap = ServerBootstrap(group: group)
            // Specify backlog and enable SO_REUSEADDR for the server itself
            .serverChannelOption(ChannelOptions.backlog, value: Int32(config.backlog))
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: config.reuseAddress ? SocketOptionValue(1) : SocketOptionValue(0))

            // Set the handlers that are applied to the accepted Channels
            .childChannelInitializer { channel in
                // create main responder handler
                let handler = HTTPServerHandler(
                    delegate: delegate,
                    maxBodySize: config.maxBodySize,
                    serverHeader: config.serverName,
                    onError: config.errorHandler
                )
                
                // create server pipeline array
                var handlers: [ChannelHandler] = []
                
                // add TLS handlers if configured
                if let tlsConfig = config.tlsConfig {
                    #warning("TODO: fix force try")
                    let sslContext = try! SSLContext(configuration: tlsConfig)
                    let tlsHandler = try! OpenSSLServerHandler(context: sslContext)
                    handlers.append(tlsHandler)
                }

                // configure HTTP/1
                do {
                    // add http parsing and serializing
                    let responseEncoder = HTTPResponseEncoder()
                    let requestDecoder = HTTPRequestDecoder(
                        leftOverBytesStrategy: .forwardBytes
                    )
                    handlers += [responseEncoder, requestDecoder]
                    handler.httpDecoder = requestDecoder
                    
                    // add pipelining support if configured
                    if config.supportPipelining {
                        //handlers.append(HTTPServerPipelineHandler())
                    }
                }
                
                // configure HTTP/2
                do {
//                    let multiplexer = HTTP2StreamMultiplexer { (channel, streamID) -> EventLoopFuture<Void> in
//                        return channel.pipeline.add(handler: HTTP2ToHTTP1ServerCodec(streamID: streamID)).then { () -> EventLoopFuture<Void> in
//                            channel.pipeline.add(handler: HTTP1TestServer())
//                        }
//                    }
//
//                    return channel.pipeline.add(handler: multiplexer)
                }
                
                if config.supportCompression {
                    handlers.append(HTTPResponseCompressor())
                }
                
                // finally add responder handler
                handlers.append(handler)
                
                // configure the pipeline
                return channel.pipeline.addHandlers(handlers, first: false)
            }

            // Enable TCP_NODELAY and SO_REUSEADDR for the accepted Channels
            .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: config.tcpNoDelay ? SocketOptionValue(1) : SocketOptionValue(0))
            .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: config.reuseAddress ? SocketOptionValue(1) : SocketOptionValue(0))
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
            // .childChannelOption(ChannelOptions.allowRemoteHalfClosure, value: 1)

        return bootstrap.bind(host: config.hostname, port: config.port).map { channel in
            return HTTPServer(channel: channel)
        }.map { server in
            // shutdown event loop when server closes
            server.onClose.whenComplete { _ in
                do {
                    try group.syncShutdownGracefully()
                } catch {
                    ERROR("Failed shutting down HTTPServer EventLoopGroup: \(error)")
                }
            }
            return server
        }
    }

    // MARK: Properties

    /// A future that will be signaled when the server closes.
    public var onClose: EventLoopFuture<Void> {
        return channel.closeFuture
    }

    /// The running channel.
    public var channel: Channel

    /// Creates a new `HTTPServer`. Use the public static `.start` method.
    private init(channel: Channel) {
        self.channel = channel
    }

    // MARK: Methods

    /// Closes the server.
    public func close() -> EventLoopFuture<Void> {
        return channel.close(mode: .all)
    }
}

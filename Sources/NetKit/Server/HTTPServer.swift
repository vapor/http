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
    public static func start(config: HTTPServerConfig) -> EventLoopFuture<HTTPServer> {
        let bootstrap = ServerBootstrap(group: config.eventLoopGroup)
            // Specify backlog and enable SO_REUSEADDR for the server itself
            .serverChannelOption(ChannelOptions.backlog, value: Int32(config.backlog))
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: config.reuseAddress ? SocketOptionValue(1) : SocketOptionValue(0))

            // Set the handlers that are applied to the accepted Channels
            .childChannelInitializer { channel in
                // create server pipeline array
                var handlers: [ChannelHandler] = []
                var otherHTTPHandlers: [ChannelHandler] = []
                
                // add TLS handlers if configured
                if let tlsConfig = config.tlsConfig {
                    #warning("TODO: fix force try")
                    let sslContext = try! SSLContext(configuration: tlsConfig)
                    let tlsHandler = try! OpenSSLServerHandler(context: sslContext)
                    handlers.append(tlsHandler)
                }

                // configure HTTP/1
                // add http parsing and serializing
                let httpResEncoder = HTTPResponseEncoder()
                let httpReqDecoder = HTTPRequestDecoder(
                    leftOverBytesStrategy: .forwardBytes
                )
                handlers += [httpResEncoder, httpReqDecoder]
                otherHTTPHandlers += [httpResEncoder]
                
                // add pipelining support if configured
                if config.supportPipelining {
                    let pipelineHandler = HTTPServerPipelineHandler()
                    handlers.append(pipelineHandler)
                    otherHTTPHandlers.append(pipelineHandler)
                }
                
                // add response compressor if configured
                if config.supportCompression {
                    let compressionHandler = HTTPResponseCompressor()
                    handlers.append(compressionHandler)
                    otherHTTPHandlers.append(compressionHandler)
                }
                
                // add NIO -> HTTP request decoder
                let serverReqDecoder = HTTPServerRequestDecoder(
                    maxBodySize: config.maxBodySize
                )
                handlers.append(serverReqDecoder)
                otherHTTPHandlers.append(serverReqDecoder)
                
                // add NIO -> HTTP response encoder
                let serverResEncoder = HTTPServerResponseEncoder(
                    serverHeader: config.serverName,
                    dateCache: .eventLoop(channel.eventLoop)
                )
                handlers.append(serverResEncoder)
                otherHTTPHandlers.append(serverResEncoder)
                
                // add server request -> response delegate
                let handler = HTTPServerHandler(
                    delegate: config.delegate,
                    errorHandler: config.errorHandler
                )
                otherHTTPHandlers.append(handler)
                
                // add HTTP upgrade handler
                let upgrader = HTTPServerUpgradeHandler(
                    httpRequestDecoder: httpReqDecoder,
                    otherHTTPHandlers: otherHTTPHandlers
                )
                handlers.append(upgrader)
                
                // wait to add delegate as final step
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

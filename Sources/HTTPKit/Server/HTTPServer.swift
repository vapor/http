import NIOTLS
import NIO
import NIOHTTP1
import NIOHTTP2

public final class HTTPServer {
    public let config: HTTPServerConfig
    public let eventLoopGroup: EventLoopGroup
    
    private var server: HTTPServerConnection?
    
    public init(config: HTTPServerConfig = .init(), on eventLoopGroup: EventLoopGroup) {
        self.config = config
        self.eventLoopGroup = eventLoopGroup
    }
    
    public func start(delegate: HTTPServerDelegate) -> EventLoopFuture<Void> {
        return HTTPServerConnection
            .start(config: self.config, on: self.eventLoopGroup, delegate: delegate)
            .map { server in
                self.server = server
            }
    }
    
    public func shutdown() -> EventLoopFuture<Void> {
        #warning("TODO: create shutdown timeout")
        let server = self.server!
        let promise = server.channel.eventLoop.makePromise(of: Void.self)
        server.quiesce.initiateShutdown(promise: promise)
        return promise.futureResult
    }
    
    public var onClose: EventLoopFuture<Void> {
        return self.server!.channel.closeFuture
    }
}

final class HTTPServerErrorHandler: ChannelInboundHandler {
    typealias InboundIn = Never
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("HTTP Server received error: \(error)")
        context.close(promise: nil)
    }
}


/// Simple HTTP server generic on an HTTP responder
/// that will be used to generate responses to incoming requests.
///
///     let server = try HTTPServer.start(hostname: hostname, port: port, responder: EchoResponder(), on: group).wait()
///     try server.onClose.wait()
///
final class HTTPServerConnection {
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
    static func start(
        config: HTTPServerConfig,
        on eventLoopGroup: EventLoopGroup,
        delegate: HTTPServerDelegate
    ) -> EventLoopFuture<HTTPServerConnection> {
        let quiesce = ServerQuiescingHelper(group: eventLoopGroup)
        let bootstrap = ServerBootstrap(group: eventLoopGroup)
            // Specify backlog and enable SO_REUSEADDR for the server itself
            .serverChannelOption(ChannelOptions.backlog, value: Int32(config.backlog))
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: config.reuseAddress ? SocketOptionValue(1) : SocketOptionValue(0))
            
            // Set handlers that are applied to the Server's channel
            .serverChannelInitializer { channel in
                channel.pipeline.addHandler(quiesce.makeServerChannelHandler(channel: channel))
            }

            // Set the handlers that are applied to the accepted Channels
            .childChannelInitializer { channel in
                // add TLS handlers if configured
                if var tlsConfig = config.tlsConfig {
                    // prioritize http/2
                    if config.supportVersions.contains(.two) {
                        tlsConfig.applicationProtocols.append("h2")
                    }
                    if config.supportVersions.contains(.one) {
                        tlsConfig.applicationProtocols.append("http/1.1")
                    }
                    let sslContext: NIOSSLContext
                    let tlsHandler: NIOSSLServerHandler
                    do {
                        sslContext = try NIOSSLContext(configuration: tlsConfig)
                        tlsHandler = try NIOSSLServerHandler(context: sslContext)
                    } catch {
                        print("Could not configure TLS: \(error)")
                        return channel.close(mode: .all)
                    }
                    return channel.pipeline.addHandler(tlsHandler).flatMap {
                        return channel.pipeline.configureHTTP2SecureUpgrade(h2PipelineConfigurator: { pipeline in
                            return channel.configureHTTP2Pipeline(mode: .server, inboundStreamStateInitializer: { channel, streamID in
                                return channel.pipeline.addHandlers(http2Handlers(
                                    config: config,
                                    delegate: delegate,
                                    channel: channel,
                                    streamID: streamID
                                ))
                            }).flatMap { _ in
                                return channel.pipeline.addHandler(HTTPServerErrorHandler())
                            }
                        }, http1PipelineConfigurator: { pipeline in
                            return pipeline.addHandlers(http1Handlers(
                                config: config,
                                delegate: delegate,
                                channel: channel
                            ))
                        })
                    }
                } else {
                    guard !config.supportVersions.contains(.two) else {
                        fatalError("Plaintext HTTP/2 (h2c) not yet supported.")
                    }
                    let handlers = http1Handlers(
                        config: config,
                        delegate: delegate,
                        channel: channel
                    )
                    // configure the pipeline
                    return channel.pipeline.addHandlers(handlers, position: .last)
                }
            }

            // Enable TCP_NODELAY and SO_REUSEADDR for the accepted Channels
            .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: config.tcpNoDelay ? SocketOptionValue(1) : SocketOptionValue(0))
            .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: config.reuseAddress ? SocketOptionValue(1) : SocketOptionValue(0))
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
            // .childChannelOption(ChannelOptions.allowRemoteHalfClosure, value: 1)

        return bootstrap.bind(host: config.hostname, port: config.port).map { channel in
            return HTTPServerConnection(channel: channel, quiesce: quiesce)
        }
    }
    
    /// The running channel.
    var channel: Channel
    
    var quiesce: ServerQuiescingHelper

    /// Creates a new `HTTPServer`. Use the public static `.start` method.
    private init(channel: Channel, quiesce: ServerQuiescingHelper) {
        self.channel = channel
        self.quiesce = quiesce
    }
}


private func http2Handlers(
    config: HTTPServerConfig,
    delegate: HTTPServerDelegate,
    channel: Channel,
    streamID: HTTP2StreamID
) -> [ChannelHandler] {
    // create server pipeline array
    var handlers: [ChannelHandler] = []
    
    let http2 = HTTP2ToHTTP1ServerCodec(streamID: streamID)
    handlers.append(http2)
    
    // add NIO -> HTTP request decoder
    let serverReqDecoder = HTTPRequestPartDecoder(
        maxBodySize: config.maxBodySize
    )
    handlers.append(serverReqDecoder)
    
    // add NIO -> HTTP response encoder
    let serverResEncoder = HTTPResponsePartEncoder(
        serverHeader: config.serverName,
        dateCache: .eventLoop(channel.eventLoop)
    )
    handlers.append(serverResEncoder)
    
    // add server request -> response delegate
    let handler = HTTPServerHandler(
        delegate: delegate,
        errorHandler: config.errorHandler
    )
    handlers.append(handler)

    return handlers
}

private func http1Handlers(
    config: HTTPServerConfig,
    delegate: HTTPServerDelegate,
    channel: Channel
) -> [ChannelHandler] {
    // create server pipeline array
    var handlers: [ChannelHandler] = []
    var otherHTTPHandlers: [RemovableChannelHandler] = []
    
    // configure HTTP/1
    // add http parsing and serializing
    let httpResEncoder = HTTPResponseEncoder()
    let httpReqDecoder = ByteToMessageHandler(HTTPRequestDecoder(
        leftOverBytesStrategy: .forwardBytes
    ))
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
    let serverReqDecoder = HTTPRequestPartDecoder(
        maxBodySize: config.maxBodySize
    )
    handlers.append(serverReqDecoder)
    otherHTTPHandlers.append(serverReqDecoder)
    
    // add NIO -> HTTP response encoder
    let serverResEncoder = HTTPResponsePartEncoder(
        serverHeader: config.serverName,
        dateCache: .eventLoop(channel.eventLoop)
    )
    handlers.append(serverResEncoder)
    otherHTTPHandlers.append(serverResEncoder)
    
    // add server request -> response delegate
    let handler = HTTPServerHandler(
        delegate: delegate,
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
    return handlers
}

import NIOTLS
import NIO
import NIOHTTP1
import NIOHTTP2

public enum HTTPVersionMajor: Equatable, Hashable {
    case one
    case two
}

/// Capable of responding to incoming `HTTPRequest`s.
public protocol HTTPServerDelegate {
    /// Responds to an incoming `HTTPRequest`.
    ///
    /// - parameters:
    ///     - req: Incoming `HTTPRequest` to respond to.
    /// - returns: Future `HTTPResponse` to send back.
    func respond(to req: HTTPRequest, on channel: Channel) -> EventLoopFuture<HTTPResponse>
}

public final class HTTPServer {
    /// Engine server config struct.
    ///
    ///     let serverConfig = HTTPServerConfig.default(port: 8123)
    ///     services.register(serverConfig)
    ///
    public struct Configuration {
        /// Host name the server will bind to.
        public var hostname: String
        
        /// Port the server will bind to.
        public var port: Int
        
        /// Listen backlog.
        public var backlog: Int
        
        /// Requests containing bodies larger than this maximum will be rejected, closing the connection.
        public var maxBodySize: Int
        
        /// When `true`, can prevent errors re-binding to a socket after successive server restarts.
        public var reuseAddress: Bool
        
        /// When `true`, OS will attempt to minimize TCP packet delay.
        public var tcpNoDelay: Bool
        
        /// Number of webSocket maxFrameSize.
        public var webSocketMaxFrameSize: Int
        
        /// When `true`, HTTP server will support gzip and deflate compression.
        public var supportCompression: Bool
        
        /// When `true`, HTTP server will support pipelined requests.
        public var supportPipelining: Bool
        
        public var supportVersions: Set<HTTPVersionMajor>
        
        public var tlsConfig: TLSConfiguration?
        
        /// If set, this name will be serialized as the `Server` header in outgoing responses.
        public var serverName: String?
        
        /// Any uncaught server or responder errors will go here.
        public var errorHandler: (Error) -> ()
        
        /// Creates a new `HTTPServerConfig`.
        ///
        /// - parameters:
        ///     - hostname: Socket hostname to bind to. Usually `localhost` or `::1`.
        ///     - port: Socket port to bind to. Usually `8080` for development and `80` for production.
        ///     - backlog: OS socket backlog size.
        ///     - workerCount: Number of `Worker`s to use for responding to incoming requests.
        ///                    This should be (and is by default) equal to the number of logical cores.
        ///     - maxBodySize: Requests with bodies larger than this maximum will be rejected.
        ///                    Streaming bodies, like chunked bodies, ignore this maximum.
        ///     - reuseAddress: When `true`, can prevent errors re-binding to a socket after successive server restarts.
        ///     - tcpNoDelay: When `true`, OS will attempt to minimize TCP packet delay.
        ///     - webSocketMaxFrameSize: Number of webSocket maxFrameSize.
        ///     - supportCompression: When `true`, HTTP server will support gzip and deflate compression.
        ///     - supportPipelining: When `true`, HTTP server will support pipelined requests.
        ///     - serverName: If set, this name will be serialized as the `Server` header in outgoing responses.
        ///     - upgraders: An array of `HTTPProtocolUpgrader` to check for with each request.
        ///     - errorHandler: Any uncaught server or responder errors will go here.
        public init(
            hostname: String = "127.0.0.1",
            port: Int = 8080,
            backlog: Int = 256,
            maxBodySize: Int = 1_000_000,
            reuseAddress: Bool = true,
            tcpNoDelay: Bool = true,
            webSocketMaxFrameSize: Int = 1 << 14,
            supportCompression: Bool = false,
            supportPipelining: Bool = false,
            supportVersions: Set<HTTPVersionMajor> = [.one, .two],
            tlsConfig: TLSConfiguration? = nil,
            serverName: String? = nil,
            errorHandler: @escaping (Error) -> () = { _ in }
        ) {
            self.hostname = hostname
            self.port = port
            self.backlog = backlog
            self.maxBodySize = maxBodySize
            self.reuseAddress = reuseAddress
            self.tcpNoDelay = tcpNoDelay
            self.webSocketMaxFrameSize = webSocketMaxFrameSize
            self.supportCompression = supportCompression
            self.supportPipelining = supportPipelining
            self.supportVersions = supportVersions
            self.tlsConfig = tlsConfig
            self.serverName = serverName
            self.errorHandler = errorHandler
        }
    }
    
    public let configuration: Configuration
    public let eventLoopGroup: EventLoopGroup

    // MARK: Properties

    /// The port the `HTTPServer` is bound to.
    ///
    /// Nil if `HTTPServer` is not bound to an IP port (eg. serving from a Unix socket or some other exotic channel).
    public var port: Int? { return channel?.localAddress?.port }

    private var channel: Channel?
    private var quiesce: ServerQuiescingHelper?
    
    public init(configuration: Configuration = .init(), on eventLoopGroup: EventLoopGroup) {
        self.configuration = configuration
        self.eventLoopGroup = eventLoopGroup
    }
    
    public func start(delegate: HTTPServerDelegate) -> EventLoopFuture<Void> {
        let quiesce = ServerQuiescingHelper(group: eventLoopGroup)
        let bootstrap = ServerBootstrap(group: eventLoopGroup)
            // Specify backlog and enable SO_REUSEADDR for the server itself
            .serverChannelOption(ChannelOptions.backlog, value: Int32(self.configuration.backlog))
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: self.configuration.reuseAddress ? SocketOptionValue(1) : SocketOptionValue(0))
            
            // Set handlers that are applied to the Server's channel
            .serverChannelInitializer { channel in
                channel.pipeline.addHandler(quiesce.makeServerChannelHandler(channel: channel))
            }
            
            // Set the handlers that are applied to the accepted Channels
            .childChannelInitializer { [weak self] channel in
                guard let self = self else {
                    fatalError("HTTP server has deinitialized")
                }
                // add TLS handlers if configured
                if var tlsConfig = self.configuration.tlsConfig {
                    // prioritize http/2
                    if self.configuration.supportVersions.contains(.two) {
                        tlsConfig.applicationProtocols.append("h2")
                    }
                    if self.configuration.supportVersions.contains(.one) {
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
                                return channel.pipeline.addHandlers(self.http2Handlers(delegate: delegate, channel: channel, streamID: streamID))
                            }).flatMap { _ in
                                return channel.pipeline.addHandler(HTTPServerErrorHandler())
                            }
                        }, http1PipelineConfigurator: { pipeline in
                            return pipeline.addHandlers(self.http1Handlers(delegate: delegate, channel: channel))
                        })
                    }
                } else {
                    guard !self.configuration.supportVersions.contains(.two) else {
                        fatalError("Plaintext HTTP/2 (h2c) not yet supported.")
                    }
                    let handlers = self.http1Handlers(delegate: delegate, channel: channel)
                    return channel.pipeline.addHandlers(handlers, position: .last)
                }
            }
            
            // Enable TCP_NODELAY and SO_REUSEADDR for the accepted Channels
            .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: self.configuration.tcpNoDelay ? SocketOptionValue(1) : SocketOptionValue(0))
            .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: self.configuration.reuseAddress ? SocketOptionValue(1) : SocketOptionValue(0))
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
        // .childChannelOption(ChannelOptions.allowRemoteHalfClosure, value: 1)
        
        return bootstrap.bind(host: self.configuration.hostname, port: self.configuration.port).map { channel in
            self.channel = channel
            self.quiesce = quiesce
        }
    }
    
    public func shutdown() -> EventLoopFuture<Void> {
        #warning("TODO: create shutdown timeout")
        guard let channel = self.channel, let quiesce = self.quiesce else {
            fatalError("Called shutdown() before start()")
        }
        let promise = channel.eventLoop.makePromise(of: Void.self)
        quiesce.initiateShutdown(promise: promise)
        return promise.futureResult
    }
    
    public var onClose: EventLoopFuture<Void> {
        guard let channel = self.channel else {
            fatalError("Called onClose before start()")
        }
        return channel.closeFuture
    }
    
    private func http2Handlers(delegate: HTTPServerDelegate, channel: Channel, streamID: HTTP2StreamID) -> [ChannelHandler] {
        // create server pipeline array
        var handlers: [ChannelHandler] = []
        
        let http2 = HTTP2ToHTTP1ServerCodec(streamID: streamID)
        handlers.append(http2)
        
        // add NIO -> HTTP request decoder
        let serverReqDecoder = HTTPRequestPartDecoder(
            maxBodySize: self.configuration.maxBodySize
        )
        handlers.append(serverReqDecoder)
        
        // add NIO -> HTTP response encoder
        let serverResEncoder = HTTPResponsePartEncoder(
            serverHeader: self.configuration.serverName,
            dateCache: .eventLoop(channel.eventLoop)
        )
        handlers.append(serverResEncoder)
        
        // add server request -> response delegate
        let handler = HTTPServerHandler(
            delegate: delegate,
            errorHandler: self.configuration.errorHandler
        )
        handlers.append(handler)
        
        return handlers
    }
    
    private func http1Handlers(delegate: HTTPServerDelegate, channel: Channel) -> [ChannelHandler] {
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
        if self.configuration.supportPipelining {
            let pipelineHandler = HTTPServerPipelineHandler()
            handlers.append(pipelineHandler)
            otherHTTPHandlers.append(pipelineHandler)
        }
        
        // add response compressor if configured
        if self.configuration.supportCompression {
            let compressionHandler = HTTPResponseCompressor()
            handlers.append(compressionHandler)
            otherHTTPHandlers.append(compressionHandler)
        }
        
        // add NIO -> HTTP request decoder
        let serverReqDecoder = HTTPRequestPartDecoder(
            maxBodySize: self.configuration.maxBodySize
        )
        handlers.append(serverReqDecoder)
        otherHTTPHandlers.append(serverReqDecoder)
        
        // add NIO -> HTTP response encoder
        let serverResEncoder = HTTPResponsePartEncoder(
            serverHeader: self.configuration.serverName,
            dateCache: .eventLoop(channel.eventLoop)
        )
        handlers.append(serverResEncoder)
        otherHTTPHandlers.append(serverResEncoder)
        
        // add server request -> response delegate
        let handler = HTTPServerHandler(
            delegate: delegate,
            errorHandler: self.configuration.errorHandler
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

    deinit {
        assert(!channel!.isActive, "HTTPServer deinitialized without calling shutdown()")
    }
}

final class HTTPServerErrorHandler: ChannelInboundHandler {
    typealias InboundIn = Never
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("HTTP Server received error: \(error)")
        context.close(promise: nil)
    }
}

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
    ///         responder: EchoResponder()
    ///     ).wait()
    ///     try server.onClose.wait()
    ///
    /// - parameters:
    ///     - config: Specifies server start options such as hostname, port, and more.
    ///     - responder: Responds to incoming requests.
    public static func start<R>(
        config: HTTPServerConfig,
        responder: R
    ) -> EventLoopFuture<HTTPServer> where R: HTTPResponder {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: config.workerCount)
        let bootstrap = ServerBootstrap(group: group)
            // Specify backlog and enable SO_REUSEADDR for the server itself
            .serverChannelOption(ChannelOptions.backlog, value: Int32(config.backlog))
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: config.reuseAddress ? SocketOptionValue(1) : SocketOptionValue(0))

            // Set the handlers that are applied to the accepted Channels
            .childChannelInitializer { channel in
                // create HTTPServerResponder-based handler
                let handler = HTTPServerHandler(
                    responder: responder,
                    maxBodySize: config.maxBodySize,
                    serverHeader: config.serverName,
                    onError: config.errorHandler
                )

                // re-use subcontainer for an event loop here
                let upgrade: HTTPUpgradeConfiguration = (upgraders: config.upgraders, completionHandler: { ctx in
                    // shouldn't need to wait for this
                    _ = channel.pipeline.remove(handler: handler)
                })

                // configure the pipeline
                return channel.pipeline.configureHTTPServerPipeline(
                    withPipeliningAssistance: config.supportPipelining,
                    withServerUpgrade: upgrade,
                    withErrorHandling: false
                ).then {
                    if config.supportCompression {
                        return channel.pipeline.addHandlers([HTTPResponseCompressor(), handler], first: false)
                    } else {
                        return channel.pipeline.add(handler: handler)
                    }
                }
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
            server.onClose.whenComplete {
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

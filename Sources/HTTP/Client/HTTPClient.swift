import Foundation

/// Connects to remote HTTP servers allowing you to send `HTTPRequest`s and
/// receive `HTTPResponse`s.
///
///     let httpRes = HTTPClient.connect(hostname: "vapor.codes", on: ...).map(to: HTTPResponse.self) { client in
///         return client.send(...)
///     }
///
public final class HTTPClient {
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
        config: HTTPClientConfig
    ) -> EventLoopFuture<HTTPClient> {
        let bootstrap = ClientBootstrap(group: config.worker.eventLoop)
            .connectTimeout(config.connectTimeout)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelInitializer { channel in
                return config.scheme.configureChannel(channel).then {
                    var handlers: [ChannelHandler] = []
                    var otherHTTPHandlers: [ChannelHandler] = []
                    
                    let httpReqEncoder = HTTPRequestEncoder()
                    handlers.append(httpReqEncoder)
                    otherHTTPHandlers.append(httpReqEncoder)
                    
                    let httpResDecoder = HTTPResponseDecoder()
                    handlers.append(httpResDecoder)
                    otherHTTPHandlers.append(httpResDecoder)
                    
                    let clientResDecoder = HTTPClientResponseDecoder()
                    handlers.append(clientResDecoder)
                    otherHTTPHandlers.append(clientResDecoder)
                    
                    let clientReqEncoder = HTTPClientRequestEncoder(hostname: config.hostname)
                    handlers.append(clientReqEncoder)
                    otherHTTPHandlers.append(clientReqEncoder)
                    
                    let upgrader = HTTPClientUpgradeHandler(otherHTTPHandlers: otherHTTPHandlers)
                    handlers.append(upgrader)
                    
                    return channel.pipeline.addHandlers(handlers, first: false)
                }
        }
        return bootstrap.connect(host: config.hostname, port: config.port ?? config.scheme.defaultPort).map { channel in
            return HTTPClient(channel: channel)
        }.map { client -> HTTPClient in
            client.onClose.whenComplete { _ in
                switch config.worker {
                case .owned(let group):
                    group.shutdownGracefully { error in
                        if let error = error {
                            ERROR("HTTPClient EventLoopGroup shutdown failed: \(error)")
                        }
                    }
                default: break
                }
            }
            return client
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
        let handler = HTTPClientHandler(promise: promise)
        self.channel.pipeline.add(handler: handler).then {
            return self.channel.writeAndFlush(NIOAny(req))
        }.cascadeFailure(promise: promise)
        return promise.futureResult.then { res in
            return self.channel.pipeline.remove(handler: handler)
                .map { _ in res }
        }
    }

    /// Closes this `HTTPClient`'s connection to the remote server.
    public func close() -> EventLoopFuture<Void> {
        return channel.close(mode: .all)
    }
}


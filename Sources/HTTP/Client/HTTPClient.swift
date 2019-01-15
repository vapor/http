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
        let handler = HTTPClientHandler()
        let bootstrap = ClientBootstrap(group: config.worker.eventLoop)
            .connectTimeout(config.connectTimeout)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelInitializer { channel in
                return config.scheme.configureChannel(channel).then {
                    let defaultHandlers: [ChannelHandler] = [
                        HTTPRequestEncoder(),
                        HTTPResponseDecoder(),
                        HTTPClientRequestSerializer(hostname: config.hostname),
                        HTTPClientResponseParser(),
                        handler
                    ]
                    return channel.pipeline.addHandlers(defaultHandlers, first: false)
                }
        }
        return bootstrap.connect(host: config.hostname, port: config.port ?? config.scheme.defaultPort).map { channel in
            return HTTPClient(channel: channel, handler: handler)
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
    
    private let handler: HTTPClientHandler

    /// A `Future` that will complete when this `HTTPClient` closes.
    public var onClose: EventLoopFuture<Void> {
        return channel.closeFuture
    }

    /// Private init for creating a new `HTTPClient`. Use the `connect` methods.
    private init(channel: Channel, handler: HTTPClientHandler) {
        self.channel = channel
        self.handler = handler
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
    public func respond(to req: HTTPRequest) -> EventLoopFuture<HTTPResponse> {
        return self.handler.send(req, on: self.channel)
    }

    /// Closes this `HTTPClient`'s connection to the remote server.
    public func close() -> EventLoopFuture<Void> {
        return channel.close(mode: .all)
    }
}

// MARK: Private

private final class HTTPClientHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPResponse
    typealias OutboundOut = HTTPRequest
    
    var waiters: [EventLoopPromise<HTTPResponse>]
    
    init() {
        self.waiters = .init()
    }
    
    func send(_ request: HTTPRequest, on channel: Channel) -> EventLoopFuture<HTTPResponse> {
        let promise = channel.eventLoop.makePromise(of: HTTPResponse.self)
        self.waiters.append(promise)
        channel.write(self.wrapOutboundOut(request))
            .cascadeFailure(promise: promise)
        channel.flush()
        return promise.futureResult
    }
    
    func errorCaught(ctx: ChannelHandlerContext, error: Error) {
        // print("PostgresConnection.ChannelHandler.errorCaught(\(error))")
        switch waiters.count {
        case 0:
            print("Discarding \(error)")
        default:
            // fail the current waiter
            let waiter = waiters.removeFirst()
            waiter.fail(error: error)
        }
    }
    
    func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
        let response = unwrapInboundIn(data)
        switch waiters.count {
        case 0:
            print("Discarding \(response)")
            break
        default:
            // succeed the current waiter
            let waiter = waiters.removeFirst()
            waiter.succeed(result: response)
        }
    }
}

/// Private `ChannelOutboundHandler` that serializes `HTTPRequest` to `HTTPClientRequestPart`.
private final class HTTPClientRequestSerializer: ChannelOutboundHandler {
    /// See `ChannelOutboundHandler`.
    typealias OutboundIn = HTTPRequest

    /// See `ChannelOutboundHandler`.
    typealias OutboundOut = HTTPClientRequestPart

    /// Hostname we are serializing responses to.
    private let hostname: String

    /// Creates a new `HTTPClientRequestSerializer`.
    init(hostname: String) {
        self.hostname = hostname
    }

    /// See `ChannelOutboundHandler`.
    func write(ctx: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let req = unwrapOutboundIn(data)
        var headers = req.headers
        headers.add(name: .host, value: hostname)
        headers.replaceOrAdd(name: .userAgent, value: "Vapor/4.0 (Swift)")
        var httpHead = HTTPRequestHead(version: req.version, method: req.method, uri: req.url.absoluteString)
        httpHead.headers = headers
        ctx.write(wrapOutboundOut(.head(httpHead)), promise: nil)
        if let data = req.body.data {
            var buffer = ByteBufferAllocator().buffer(capacity: data.count)
            buffer.write(bytes: data)
            ctx.write(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        }
        ctx.write(self.wrapOutboundOut(.end(nil)), promise: nil)
    }
}

/// Private `ChannelInboundHandler` that parses `HTTPClientResponsePart` to `HTTPResponse`.
private final class HTTPClientResponseParser: ChannelInboundHandler {
    /// See `ChannelInboundHandler`.
    typealias InboundIn = HTTPClientResponsePart

    /// See `ChannelInboundHandler`.
    typealias OutboundOut = HTTPResponse

    /// Current state.
    private var state: HTTPClientState

    /// Creates a new `HTTPClientResponseParser`.
    init() {
        self.state = .ready
    }

    /// See `ChannelInboundHandler`.
    func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
        switch unwrapInboundIn(data) {
        case .head(let head):
            switch state {
            case .ready: state = .parsingBody(head, nil)
            case .parsingBody: assert(false, "Unexpected HTTPClientResponsePart.head when body was being parsed.")
            }
        case .body(var body):
            switch state {
            case .ready: assert(false, "Unexpected HTTPClientResponsePart.body when awaiting request head.")
            case .parsingBody(let head, let existingData):
                let data: Data
                if var existing = existingData {
                    existing += body.readData(length: body.readableBytes) ?? Data()
                    data = existing
                } else {
                    data = body.readData(length: body.readableBytes) ?? Data()
                }
                state = .parsingBody(head, data)
            }
        case .end(let tailHeaders):
            assert(tailHeaders == nil, "Unexpected tail headers")
            switch state {
            case .ready: assert(false, "Unexpected HTTPClientResponsePart.end when awaiting request head.")
            case .parsingBody(let head, let data):
                let body: HTTPBody = data.flatMap { .init(data: $0) } ?? .init()
                let res = HTTPResponse(status: head.status, version: head.version, headersNoUpdate: head.headers, body: body)
                ctx.fireChannelRead(wrapOutboundOut(res))
                state = .ready
            }
        }
    }
}

/// Tracks `HTTPClientHandler`'s state.
private enum HTTPClientState {
    /// Waiting to parse the next response.
    case ready
    /// Currently parsing the response's body.
    case parsingBody(HTTPResponseHead, Data?)
}

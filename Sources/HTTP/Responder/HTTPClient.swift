/// Connects to remote HTTP servers allowing you to send `HTTPRequest`s and
/// receive `HTTPResponse`s.
///
/// See `connect(...)` and `connectTLS(...)` to create an `HTTPClient`.
public final class HTTPClient {
    /// Creates a new `HTTPClient` connected over TCP.
    ///
    ///     let httpRes = HTTPClient.connect(hostname: "vapor.codes", on: req).map(to: HTTPResponse.self) { client in
    ///         return client.send(...)
    ///     }
    ///
    /// - parameters:
    ///     - hostname: Remote server's hostname.
    ///     - port: Remote server's port, defaults to 80 for TCP.
    ///     - worker: `Worker` to perform async work on.
    /// - returns: A `Future` containing the connected `HTTPClient`.
    public static func connect(hostname: String, port: Int = 80, on worker: Worker) -> Future<HTTPClient> {
        return _connect(hostname: hostname, port: port, on: worker) { pipeline in
            return .done(on: pipeline.eventLoop)
        }
    }

    /// Creates a new `HTTPClient` connected over TLS.
    ///
    ///     let httpRes = HTTPClient.connectTLS(hostname: "vapor.codes", on: req).map(to: HTTPResponse.self) { client in
    ///         return client.send(...)
    ///     }
    ///
    /// - parameters:
    ///     - hostname: Remote server's hostname.
    ///     - port: Remote server's port, defaults to 443 for TLS.
    ///     - worker: `Worker` to perform async work on.
    /// - returns: A `Future` containing the connected `HTTPClient`.
    public static func connectTLS(hostname: String, port: Int = 443, on worker: Worker) throws -> Future<HTTPClient> {
        let tlsConfiguration = TLSConfiguration.forClient(certificateVerification: .none)
        let sslContext = try SSLContext(configuration: tlsConfiguration)
        let tlsHandler = try OpenSSLClientHandler(context: sslContext)
        return _connect(hostname: hostname, port: port, on: worker) { pipeline in
            return pipeline.add(handler: tlsHandler)
        }
    }

    /// Internal connect method that allows for configuration of the `ChannelPipeline`.
    private static func _connect(hostname: String, port: Int, on worker: Worker, config: @escaping (ChannelPipeline) -> Future<Void>) -> Future<HTTPClient> {
        let handler = QueueHandler<HTTPResponse, HTTPRequest>(on: worker) { error in
            ERROR("HTTPClient: \(error)")
        }
        let bootstrap = ClientBootstrap(group: worker.eventLoop)
            // Enable SO_REUSEADDR.
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelInitializer { channel in
                return config(channel.pipeline).then {
                    channel.pipeline.addHandlers(
                        HTTPRequestEncoder(),
                        HTTPResponseDecoder(),

                        HTTPClientRequestSerializer(),
                        HTTPClientResponseParser(),
                        
                        handler,
                        first: false
                    )
            }
        }

        return bootstrap.connect(host: hostname, port: port).map(to: HTTPClient.self) { channel in
            return .init(handler: handler, channel: channel)
        }
    }

    /// Private `HTTPClientHandler` that handles requests.
    private let handler: QueueHandler<HTTPResponse, HTTPRequest>

    /// Private NIO channel powering this client.
    private let channel: Channel

    /// A `Future` that will complete when this `HTTPClient` closes.
    public var onClose: Future<Void> {
        return channel.closeFuture
    }

    /// Private init for creating a new `HTTPClient`. Use the `connect` methods.
    private init(handler: QueueHandler<HTTPResponse, HTTPRequest>, channel: Channel) {
        self.handler = handler
        self.channel = channel
    }

    /// Closes this `HTTPClient`'s connection to the remote server.
    public func close() -> Future<Void> {
        return channel.close(mode: .all)
    }

    /// Sends an `HTTPRequest` to the connected, remote server.
    ///
    ///     let httpRes = HTTPClient.connect(hostname: "vapor.codes", on: req).map(to: HTTPResponse.self) { client in
    ///         return client.send(...)
    ///     }
    ///
    /// - parameters:
    ///     - request: `HTTPRequest` to send to the remote server.
    /// - returns: A `Future` `HTTPResponse` containing the server's response.
    public func send(_ request: HTTPRequest) -> Future<HTTPResponse> {
        var res: HTTPResponse?
        return handler.enqueue([request]) { _res in
            res = _res
            return true
        }.map(to: HTTPResponse.self) {
            return res!
        }
    }
}

// MARK: Private

/// Private `ChannelOutboundHandler` that serializes `HTTPRequest` to `HTTPClientRequestPart`.
private final class HTTPClientRequestSerializer: ChannelOutboundHandler {
    /// See `ChannelOutboundHandler`.
    typealias OutboundIn = HTTPRequest

    /// See `ChannelOutboundHandler`.
    typealias OutboundOut = HTTPClientRequestPart

    /// Creates a new `HTTPClientRequestSerializer`.
    init() { }

    /// See `ChannelOutboundHandler`.
    func write(ctx: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let req = unwrapOutboundIn(data)
        var headers = req.headers
        if let contentLength = req.body.count {
            headers.replaceOrAdd(name: .contentLength, value: contentLength.description)
        } else {
            headers.replaceOrAdd(name: .contentLength, value: "0")
        }
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
                let res = HTTPResponse(
                    status: head.status,
                    version: head.version,
                    headersNoUpdate: head.headers,
                    body: data.flatMap { HTTPBody(data: $0) } ?? HTTPBody()
                )
                ctx.fireChannelRead(wrapOutboundOut(res))
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

import Foundation
import NIO
import NIOHTTP1

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
    ///     let httpRes = HTTPClient.connect(hostname: "vapor.codes", on: ...).map(to: HTTPResponse.self) { client in
    ///         return client.send(...)
    ///     }
    ///
    /// - parameters:
    ///     - scheme: Transport layer security to use, either tls or plainText.
    ///     - hostname: Remote server's hostname.
    ///     - port: Remote server's port, defaults to 80 for TCP and 443 for TLS.
    ///     - connectTimeout: The timeout that will apply to the connection attempt.
    ///     - worker: `Worker` to perform async work on.
    ///     - onError: Optional closure, which fires when a networking error is caught.
    /// - returns: A `Future` containing the connected `HTTPClient`.
    public static func connect(
        scheme: HTTPScheme = .http,
        hostname: String,
        port: Int? = nil,
        connectTimeout: TimeAmount = TimeAmount.seconds(10),
        on eventLoop: EventLoop,
        onError: @escaping (Error) -> () = { _ in }
    ) -> EventLoopFuture<HTTPClient> {
        #warning("TODO: replace missing queue handler")
        let bootstrap = ClientBootstrap(group: eventLoop)
            .connectTimeout(connectTimeout)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelInitializer { channel in
                return scheme.configureChannel(channel).then {
                    let defaultHandlers: [ChannelHandler] = [
                        HTTPRequestEncoder(),
                        HTTPResponseDecoder(),
                        HTTPClientRequestSerializer(hostname: hostname),
                        HTTPClientResponseParser()
                    ]
                    return channel.pipeline.addHandlers(defaultHandlers, first: false)
                }
        }
        return bootstrap.connect(host: hostname, port: port ?? scheme.defaultPort).map { channel in
            return .init(channel: channel)
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
    ///         return client.send(...)
    ///     }
    ///
    /// - parameters:
    ///     - request: `HTTPRequest` to send to the remote server.
    /// - returns: A `Future` `HTTPResponse` containing the server's response.
    public func send(_ request: HTTPRequest) -> EventLoopFuture<HTTPResponse> {
        #warning("TODO: implement me")
        return self.channel.eventLoop.makeSucceededFuture(result: .init())
//        return handler.enqueue([request]) { _res in
//            res = _res
//            return true
//        }.map(to: HTTPResponse.self) {
//            return res!
//        }
    }

    /// Closes this `HTTPClient`'s connection to the remote server.
    public func close() -> EventLoopFuture<Void> {
        return channel.close(mode: .all)
    }
}

// MARK: Private

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
        headers.replaceOrAdd(name: .userAgent, value: "Vapor/3.0 (Swift)")
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
                let res = HTTPResponse(head: head, body: body, channel: ctx.channel)
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

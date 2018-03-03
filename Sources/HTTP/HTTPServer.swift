import Foundation

/// Simple HTTP server generic on an HTTP responder
/// that will be used to generate responses to incoming requests.
public final class HTTPServer {
    /// The running channel.
    private var channel: Channel

    /// Creates a new `HTTPServer`. Use the public static `.start` method.
    private init(channel: Channel) {
        self.channel = channel
    }

    /// Starts the server on the supplied hostname and port, using the supplied
    /// responder to generate HTTP responses for incoming requests.
    ///
    /// - parameters:
    ///     - hostname: Socket hostname to bind to. Usually `localhost` or `::1`.
    ///     - port: Socket port to bind to. Usually `8080` for development and `80` for production.
    ///     - responder: Used to generate responses for incoming requests.
    ///     - maxBodySize: Requests with bodies larger than this maximum will be rejected.
    ///                    Streaming bodies, like chunked bodies, ignore this maximum.
    ///     - threadCount: The number of threads to use for responding to requests.
    ///                    This defaults to `System.coreCount` which is recommended.
    ///     - backlog: OS socket backlog size.
    ///     - reuseAddress: When `true`, can prevent errors re-binding to a socket after successive server restarts.
    ///     - tcpNoDelay: When `true`, OS will attempt to minimize TCP packet delay.
    ///     - onError: Any uncaught server or responder errors will go here.
    public static func start(
        hostname: String,
        port: Int,
        responder: HTTPResponder,
        maxBodySize: Int = 1_000_000,
        backlog: Int = 256,
        reuseAddress: Bool = true,
        tcpNoDelay: Bool = true,
        on worker: Worker,
        onError: @escaping (Error) -> () = { _ in }
    ) -> Future<HTTPServer> {
        let bootstrap = ServerBootstrap(group: worker)
            // Specify backlog and enable SO_REUSEADDR for the server itself
            .serverChannelOption(ChannelOptions.backlog, value: Int32(backlog))
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: reuseAddress ? SocketOptionValue(1) : SocketOptionValue(0))

            // Set the handlers that are applied to the accepted Channels
            .childChannelInitializer { channel in
                // re-use subcontainer for an event loop here
                return channel.pipeline.addHTTPServerHandlers().then {
                    let handler = HTTPServerHandler(responder: responder, maxBodySize: maxBodySize, onError: onError)
                    return channel.pipeline.add(handler: handler)
                }
            }

            // Enable TCP_NODELAY and SO_REUSEADDR for the accepted Channels
            .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: tcpNoDelay ? SocketOptionValue(1) : SocketOptionValue(0))
            .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: reuseAddress ? SocketOptionValue(1) : SocketOptionValue(0))
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)

        return bootstrap.bind(host: hostname, port: port).map(to: HTTPServer.self) { channel in
            return HTTPServer(channel: channel)
        }
    }

    /// A future that will be signaled when the server closes.
    public var onClose: Future<Void> {
        return channel.closeFuture
    }

    /// Closes the server.
    public func close() -> Future<Void> {
        return channel.close(mode: .all)
    }
}

internal final class HTTPServerHandler: ChannelInboundHandler {
    public typealias InboundIn = HTTPServerRequestPart
    public typealias OutboundOut = HTTPServerResponsePart

    /// The responder generating `HTTPResponse`s for incoming `HTTPRequest`s.
    public let responder: HTTPResponder

    /// Maximum body size allowed per request.
    private let maxBodySize: Int

    /// Handles any errors that may occur.
    private let errorHandler: (Error) -> ()

    var state: HTTPServerState

    /// Create a new `HTTPServer` using the supplied `HTTPResponder`
    init(responder: HTTPResponder, maxBodySize: Int = 1_000_000, onError: @escaping (Error) -> ()) {
        self.responder = responder
        self.maxBodySize = maxBodySize
        self.errorHandler = onError
        self.state = .ready
    }

    func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
        assert(ctx.channel.eventLoop.inEventLoop)
        let req = unwrapInboundIn(data)
        switch req {
        case .head(let head):
            switch state {
            case .ready:
                if head.headers[.transferEncoding].first == "chunked" {
                    let stream = HTTPChunkedStream(on: ctx.eventLoop)
                    state = .streamingBody(stream)
                    writeResponse(for: head, body: .init(chunked: stream), ctx: ctx)
                } else {
                    state = .collectingBody(head, nil)
                }
            default: fatalError("Unexpected state: \(state)")
            }
        case .body(var chunk):
            switch state {
            case .ready: fatalError()
            case .collectingBody(let head, let existingBody):
                let body: ByteBuffer
                if var existing = existingBody {
                    if existing.readableBytes + chunk.readableBytes > self.maxBodySize {
                        print("[ERROR] [HTTP] Request size exceeded maximum, connection closed.")
                        ctx.close(promise: nil)
                    }
                    existing.write(buffer: &chunk)
                    body = existing
                } else {
                    body = chunk
                }
                state = .collectingBody(head, body)
            case .streamingBody(let stream): _ = stream.write(.chunk(chunk))
            }
        case .end(let tailHeaders):
            assert(tailHeaders == nil)
            switch state {
            case .ready: fatalError()
            case .collectingBody(let head, let body):
                writeResponse(
                    for: head,
                    body: body.flatMap { HTTPBody(buffer: $0) } ?? HTTPBody(),
                    ctx: ctx
                )
            case .streamingBody(let stream): _ = stream.write(.end)
            }
            state = .ready
        }
    }

    private func writeResponse(for head: HTTPRequestHead, body: HTTPBody, ctx: ChannelHandlerContext) {
        let req = HTTPRequest(
            method: head.method,
            url: URL(string: head.uri)!,
            version: head.version,
            headersNoUpdate: head.headers,
            body: body
        )
        responder.respond(to: req, on: ctx.eventLoop).do { res in
            switch body.storage {
            case .chunkedStream(let stream):
                if !stream.isClosed {
                    print("[WARNING] [HTTP] Response sent while Request had unconsumed chunked data.")
                }
            default: break
            }
            let httpHead = HTTPResponseHead(version: res.version, status: res.status, headers: res.headers)
            ctx.write(self.wrapOutboundOut(.head(httpHead)), promise: nil)

            switch res.body.storage {
            case .none:
                // optimized case, just send end
                ctx.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
            case .chunkedStream(let stream):
                stream.read { result, stream in
                    switch result {
                    case .chunk(let buffer):
                        return ctx.writeAndFlush(self.wrapOutboundOut(.body(.byteBuffer(buffer))))
                    case .end:
                        return ctx.writeAndFlush(self.wrapOutboundOut(.end(nil)))
                    case .error(let error):
                        self.errorHandler(error)
                        return ctx.writeAndFlush(self.wrapOutboundOut(.end(nil)))
                    }
                }
            default:
                var buffer = ByteBufferAllocator().buffer(capacity: res.body.count ?? 0)
                switch res.body.storage {
                case .buffer(var body): buffer.write(buffer: &body)
                case .data(let data): buffer.write(bytes: data)
                case .dispatchData(let data): buffer.write(bytes: data)
                case .none: break
                case .chunkedStream: break
                case .staticString(let string): buffer.write(bytes: string)
                case .string(let string): buffer.write(string: string)
                }
                if buffer.readableBytes > 0 {
                    ctx.write(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
                }
                ctx.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
            }
        }.catch { error in
            self.errorHandler(error)
            ctx.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
            ctx.close(promise: nil)
        }
    }

    func errorCaught(ctx: ChannelHandlerContext, error: Error) {
        errorHandler(error)
    }

    func channelReadComplete(ctx: ChannelHandlerContext) { }
    func handlerAdded(ctx: ChannelHandlerContext) { }
}

enum HTTPServerState {
    case ready
    case collectingBody(HTTPRequestHead, ByteBuffer?)
    case streamingBody(HTTPChunkedStream)
}

public struct HTTPRunningServer {
    private var channel: Channel
}

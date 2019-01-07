import NIO
import NIOHTTP1

/// Private `ChannelInboundHandler` that converts `HTTPServerRequestPart` to `HTTPServerResponsePart`.
internal final class HTTPServerHandler<R>: ChannelInboundHandler where R: HTTPResponder {
    /// See `ChannelInboundHandler`.
    public typealias InboundIn = HTTPServerRequestPart
    
    /// See `ChannelInboundHandler`.
    public typealias OutboundOut = HTTPServerResponsePart
    
    /// The responder generating `HTTPResponse`s for incoming `HTTPRequest`s.
    public let responder: R
    
    /// Maximum body size allowed per request.
    private let maxBodySize: Int
    
    /// Handles any errors that may occur.
    private let errorHandler: (Error) -> ()
    
    /// Optional server header.
    private let serverHeader: String?
    
    /// Current HTTP state.
    private var state: HTTPServerHandlerState
    
    /// Create a new `HTTPServerHandler`.
    init(responder: R, maxBodySize: Int = 1_000_000, serverHeader: String?, onError: @escaping (Error) -> ()) {
        self.responder = responder
        self.maxBodySize = maxBodySize
        self.errorHandler = onError
        self.serverHeader = serverHeader
        self.state = .ready
    }
    
    /// See `ChannelInboundHandler`.
    func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
        assert(ctx.channel.eventLoop.inEventLoop)
        switch unwrapInboundIn(data) {
        case .head(let head):
            switch self.state {
            case .ready: self.state = .awaitingBody(head)
            default: assertionFailure("Unexpected state: \(state)")
            }
        case .body(var chunk):
            switch self.state {
            case .ready: assertionFailure("Unexpected state: \(state)")
            case .awaitingBody(let head):
                /// 1: check to see which kind of body we are parsing from the head
                ///
                /// short circuit on `contains(name:)` which is faster
                /// - note: for some reason using String instead of HTTPHeaderName is faster here...
                ///         this will be standardized when NIO gets header names
                if head.headers.contains(name: "Transfer-Encoding"), head.headers.firstValue(name: .transferEncoding) == "chunked" {
                    let stream = HTTPChunkedStream(on: ctx.eventLoop)
                    self.state = .streamingBody(stream)
                    self.respond(to: head, body: .init(chunked: stream), ctx: ctx)
                } else {
                    self.state = .collectingBody(head, nil)
                }
                
                /// 2: perform the actual body read now
                channelRead(ctx: ctx, data: data)
            case .collectingBody(let head, let existingBody):
                let body: ByteBuffer
                if var existing = existingBody {
                    if existing.readableBytes + chunk.readableBytes > self.maxBodySize {
                        ERROR("[HTTP] Request size exceeded maximum, connection closed.")
                        ctx.close(promise: nil)
                    }
                    existing.write(buffer: &chunk)
                    body = existing
                } else {
                    body = chunk
                }
                self.state = .collectingBody(head, body)
            case .streamingBody(let stream): _ = stream.write(.chunk(chunk))
            }
        case .end(let tailHeaders):
            assert(tailHeaders == nil, "Tail headers are not supported.")
            switch state {
            case .ready: assertionFailure("Unexpected state: \(state)")
            case .awaitingBody(let head): respond(to: head, body: .empty, ctx: ctx)
            case .collectingBody(let head, let body):
                let body: HTTPBody = body.flatMap(HTTPBody.init(buffer:)) ?? .empty
                respond(to: head, body: body, ctx: ctx)
            case .streamingBody(let stream): _ = stream.write(.end)
            }
            self.state = .ready
        }
    }
    
    /// Requests an `HTTPResponse` from the responder and serializes it.
    private func respond(to head: HTTPRequestHead, body: HTTPBody, ctx: ChannelHandlerContext) {
        let req = HTTPRequest(head: head, body: body, channel: ctx.channel)
        switch head.method {
        case .HEAD: req.method = .GET
        default: break
        }
        let res = responder.respond(to: req)
        res.whenSuccess { res in
            switch body.storage {
            case .chunkedStream(let stream): assert(stream.isClosed, "HTTPResponse sent while HTTPRequest had unconsumed chunked data.")
            default: break
            }
            self.serialize(res, for: req, ctx: ctx)
        }
        res.whenFailure { error in
            self.errorHandler(error)
            ctx.close(promise: nil)
        }
    }
    
    /// Serializes the `HTTPResponse`.
    private func serialize(_ res: HTTPResponse, for req: HTTPRequest, ctx: ChannelHandlerContext) {
        // add a RFC1123 timestamp to the Date header to make this
        // a valid request
        res.head.headers.add(name: "date", value: RFC1123DateCache.shared.currentTimestamp())
        
        if let server = self.serverHeader {
            res.head.headers.add(name: "server", value: server)
        }
        
        // add 'Connection' header if needed
        res.head.headers.add(name: .connection, value: req.head.isKeepAlive ? "keep-alive" : "close")
        
        // begin serializing
        ctx.write(wrapOutboundOut(.head(res.head)), promise: nil)
        if req.head.method == .HEAD || res.head.status == .noContent {
            // skip sending the body for HEAD requests
            // also don't send bodies for 204 (no content) requests
            ctx.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
        } else {
            switch res.body.storage {
            case .none: ctx.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
            case .buffer(let buffer): self.writeAndflush(buffer: buffer, ctx: ctx, shouldClose: !req.head.isKeepAlive)
            case .string(let string):
                var buffer = ctx.channel.allocator.buffer(capacity: string.count)
                buffer.write(string: string)
                self.writeAndflush(buffer: buffer, ctx: ctx, shouldClose: !req.head.isKeepAlive)
            case .staticString(let string):
                var buffer = ctx.channel.allocator.buffer(capacity: string.utf8CodeUnitCount)
                buffer.write(staticString: string)
                self.writeAndflush(buffer: buffer, ctx: ctx, shouldClose: !req.head.isKeepAlive)
            case .data(let data):
                var buffer = ctx.channel.allocator.buffer(capacity: data.count)
                buffer.write(bytes: data)
                self.writeAndflush(buffer: buffer, ctx: ctx, shouldClose: !req.head.isKeepAlive)
            case .dispatchData(let data):
                var buffer = ctx.channel.allocator.buffer(capacity: data.count)
                buffer.write(bytes: data)
                self.writeAndflush(buffer: buffer, ctx: ctx, shouldClose: !req.head.isKeepAlive)
            case .chunkedStream(let stream):
                stream.read { result, stream in
                    let future: EventLoopFuture<Void>
                    switch result {
                    case .chunk(let buffer):
                        future = ctx.writeAndFlush(self.wrapOutboundOut(.body(.byteBuffer(buffer))))
                    case .end:
                        future = ctx.writeAndFlush(self.wrapOutboundOut(.end(nil)))
                    case .error(let error):
                        self.errorHandler(error)
                        future = ctx.writeAndFlush(self.wrapOutboundOut(.end(nil)))
                    }
                    
                    if !req.head.isKeepAlive {
                        switch result {
                        case .end, .error:
                            return future.map {
                                ctx.close(promise: nil)
                            }
                        default: return future
                        }
                    } else {
                        return future
                    }
                }
            }
        }
    }
    /// Writes a `ByteBuffer` to the ctx.
    private func writeAndflush(buffer: ByteBuffer, ctx: ChannelHandlerContext, shouldClose: Bool) {
        if buffer.readableBytes > 0 {
            _ = ctx.write(wrapOutboundOut(.body(.byteBuffer(buffer))))
        }
        _ = ctx.writeAndFlush(wrapOutboundOut(.end(nil))).map {
            if shouldClose {
                // close connection now
                ctx.close(promise: nil)
            }
        }
    }
    
    /// See `ChannelInboundHandler`.
    func errorCaught(ctx: ChannelHandlerContext, error: Error) {
        self.errorHandler(error)
    }
}

/// Tracks current HTTP server state
private enum HTTPServerHandlerState {
    /// Waiting for request headers
    case ready
    /// Waiting for the body
    /// This allows for performance optimization incase
    /// a body never comes
    case awaitingBody(HTTPRequestHead)
    /// Collecting fixed-length body
    case collectingBody(HTTPRequestHead, ByteBuffer?)
    /// Collecting streaming body
    case streamingBody(HTTPChunkedStream)
}


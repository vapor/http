import NIO
import NIOHTTP1

/// Private `ChannelInboundHandler` that converts `HTTPServerRequestPart` to `HTTPServerResponsePart`.
internal final class HTTPServerHandler<Delegate>: ChannelInboundHandler where Delegate: HTTPServerDelegate {
    /// See `ChannelInboundHandler`.
    public typealias InboundIn = HTTPServerRequestPart
    
    /// See `ChannelInboundHandler`.
    public typealias OutboundOut = HTTPServerResponsePart
    
    /// The responder generating `HTTPResponse`s for incoming `HTTPRequest`s.
    public let delegate: Delegate
    
    /// Maximum body size allowed per request.
    private let maxBodySize: Int
    
    /// Handles any errors that may occur.
    private let errorHandler: (Error) -> ()
    
    /// Optional server header.
    private let serverHeader: String?
    
    /// Current HTTP state.
    private var state: HTTPServerHandlerState
    
    private var upgradeState: HTTPServerUpgradeState
    
    /// Used to remove / re-add HTTP decoder during upgrade
    internal var httpDecoder: ChannelHandler?
    
    /// Create a new `HTTPServerHandler`.
    init(delegate: Delegate, maxBodySize: Int = 1_000_000, serverHeader: String?, onError: @escaping (Error) -> ()) {
        self.delegate = delegate
        self.maxBodySize = maxBodySize
        self.errorHandler = onError
        self.serverHeader = serverHeader
        self.state = .ready
        self.upgradeState = .ready
    }
    
    /// See `ChannelInboundHandler`.
    func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
        assert(ctx.channel.eventLoop.inEventLoop)
        print(self.unwrapInboundIn(data))
        switch self.unwrapInboundIn(data) {
        case .head(let head):
            switch self.state {
            case .ready:
                self.state = .awaitingBody(head)
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
                self.channelRead(ctx: ctx, data: data)
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
            case .awaitingBody(let head):
                if head.headers[canonicalForm: "connection"].contains("upgrade") {
                    // remove http decoder
                    print("go to pending status")
                    let buffer = UpgradeBufferHandler()
                    _ = ctx.channel.pipeline.add(handler: buffer, after: self.httpDecoder!).then {
                        return ctx.channel.pipeline.remove(handler: self.httpDecoder!)
                    }
                    self.upgradeState = .pending(buffer)
                }
                self.respond(to: head, body: .empty, ctx: ctx)
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
        var req = HTTPRequest(method: head.method, urlString: head.uri, version: head.version, headersNoUpdate: head.headers, body: body)
        switch head.method {
        case .HEAD: req.method = .GET
        default: break
        }
        let res = self.delegate.respond(to: req, on: ctx.channel)
        res.whenSuccess { res in
            switch body.storage {
            case .chunkedStream(let stream): assert(stream.isClosed, "HTTPResponse sent while HTTPRequest had unconsumed chunked data.")
            default: break
            }
            self.serialize(res, for: head, ctx: ctx)
        }
        res.whenFailure { error in
            self.errorHandler(error)
            ctx.close(promise: nil)
        }
    }
    
    /// Serializes the `HTTPResponse`.
    private func serialize(_ res: HTTPResponse, for req: HTTPRequestHead, ctx: ChannelHandlerContext) {
        var res = res
        // add a RFC1123 timestamp to the Date header to make this
        // a valid request
        res.headers.add(name: "date", value: RFC1123DateCache.shared.currentTimestamp())
        
        if let server = self.serverHeader {
            res.headers.add(name: "server", value: server)
        }
        
        // add 'Connection' header if needed
        let isKeepAlive = req.isKeepAlive
        res.headers.add(name: .connection, value: isKeepAlive ? "keep-alive" : "close")
        
        // begin serializing
        ctx.write(wrapOutboundOut(.head(.init(version: res.version, status: res.status, headers: res.headers))), promise: nil)
        if req.method == .HEAD || res.status == .noContent {
            // skip sending the body for HEAD requests
            // also don't send bodies for 204 (no content) requests
            ctx.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
        } else {
            switch res.body.storage {
            case .none: ctx.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
            case .buffer(let buffer): self.writeAndflush(buffer: buffer, ctx: ctx, shouldClose: !isKeepAlive)
            case .string(let string):
                var buffer = ctx.channel.allocator.buffer(capacity: string.count)
                buffer.write(string: string)
                self.writeAndflush(buffer: buffer, ctx: ctx, shouldClose: !isKeepAlive)
            case .staticString(let string):
                var buffer = ctx.channel.allocator.buffer(capacity: string.utf8CodeUnitCount)
                buffer.write(staticString: string)
                self.writeAndflush(buffer: buffer, ctx: ctx, shouldClose: !isKeepAlive)
            case .data(let data):
                var buffer = ctx.channel.allocator.buffer(capacity: data.count)
                buffer.write(bytes: data)
                self.writeAndflush(buffer: buffer, ctx: ctx, shouldClose: !isKeepAlive)
            case .dispatchData(let data):
                var buffer = ctx.channel.allocator.buffer(capacity: data.count)
                buffer.write(bytes: data)
                self.writeAndflush(buffer: buffer, ctx: ctx, shouldClose: !isKeepAlive)
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
                    
                    if !isKeepAlive {
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
        
        // check upgrade
        switch self.upgradeState {
        case .pending(let buffer):
            if res.status == .switchingProtocols, let upgrader = res.upgrader {
                // do upgrade
                _ = upgrader.upgrade(ctx: ctx, upgradeRequest: req).then {
                    return ctx.channel.pipeline.remove(handler: buffer)
                }
                print("DO UPGRADE: \(upgrader)")
                self.upgradeState = .upgraded
            } else {
                // reset handlers
                print("go to ready status")
                self.upgradeState = .ready
                _ = ctx.channel.pipeline.add(handler: self.httpDecoder!, after: buffer).then {
                    return ctx.channel.pipeline.remove(handler: buffer)
                }
            }
        case .ready: break
        case .upgraded: break
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

private enum HTTPServerUpgradeState {
    case ready
    case pending(UpgradeBufferHandler)
    case upgraded
}


private final class UpgradeBufferHandler: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer
    
    var buffer: [ByteBuffer]
    
    init() {
        self.buffer = []
    }
    
    func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
        let data = self.unwrapInboundIn(data)
        self.buffer.append(data)
    }
    
    func handlerRemoved(ctx: ChannelHandlerContext) {
        print("forwarding \(self.buffer.count) buffers")
        for data in self.buffer {
            ctx.fireChannelRead(NIOAny(data))
        }
    }
}

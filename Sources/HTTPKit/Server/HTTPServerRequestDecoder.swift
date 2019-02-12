// import Logging

final class HTTPServerRequestDecoder: ChannelInboundHandler, RemovableChannelHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias InboundOut = HTTPRequest
    
    /// Tracks current HTTP server state
    enum RequestState {
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
    
    /// Current HTTP state.
    var requestState: RequestState
    
    /// Maximum body size allowed per request.
    private let maxBodySize: Int
    
    // private let logger: Logger
    
    init(maxBodySize: Int) {
        self.maxBodySize = maxBodySize
        self.requestState = .ready
        // self.logger = Logging.make("http-kit.server-decoder")
    }
    
    func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
        assert(ctx.channel.eventLoop.inEventLoop)
        switch self.unwrapInboundIn(data) {
        case .head(let head):
            // self.logger.trace("got req head \(head)")
            switch self.requestState {
            case .ready: self.requestState = .awaitingBody(head)
            default: assertionFailure("Unexpected state: \(self.requestState)")
            }
        case .body(var chunk):
            // self.logger.trace("got req body \(chunk)")
            switch self.requestState {
            case .ready: assertionFailure("Unexpected state: \(self.requestState)")
            case .awaitingBody(let head):
                /// 1: check to see which kind of body we are parsing from the head
                ///
                /// short circuit on `contains(name:)` which is faster
                /// - note: for some reason using String instead of HTTPHeaderName is faster here...
                ///         this will be standardized when NIO gets header names
                if head.headers.contains(name: "Transfer-Encoding"), head.headers.firstValue(name: .transferEncoding) == "chunked" {
                    let stream = HTTPChunkedStream(on: ctx.eventLoop)
                    self.requestState = .streamingBody(stream)
                    self.respond(to: head, body: .init(chunked: stream), ctx: ctx)
                } else {
                    self.requestState = .collectingBody(head, nil)
                }
                
                /// 2: perform the actual body read now
                self.channelRead(ctx: ctx, data: data)
            case .collectingBody(let head, let existingBody):
                let body: ByteBuffer
                if var existing = existingBody {
                    if existing.readableBytes + chunk.readableBytes > self.maxBodySize {
                        // Request size exceeded maximum, connection closed.
                        ctx.close(promise: nil)
                    }
                    existing.writeBuffer(&chunk)
                    body = existing
                } else {
                    body = chunk
                }
                self.requestState = .collectingBody(head, body)
            case .streamingBody(let stream): _ = stream.write(.chunk(chunk))
            }
        case .end(let tailHeaders):
            // self.logger.trace("got req end")
            assert(tailHeaders == nil, "Tail headers are not supported.")
            switch self.requestState {
            case .ready: assertionFailure("Unexpected state: \(self.requestState)")
            case .awaitingBody(let head): self.respond(to: head, body: .empty, ctx: ctx)
            case .collectingBody(let head, let body):
                let body: HTTPBody = body.flatMap(HTTPBody.init(buffer:)) ?? .empty
                self.respond(to: head, body: body, ctx: ctx)
            case .streamingBody(let stream): _ = stream.write(.end)
            }
            self.requestState = .ready
        }
    }
    
    private func respond(to head: HTTPRequestHead, body: HTTPBody, ctx: ChannelHandlerContext) {
        var req = HTTPRequest(
            method: head.method,
            urlString: head.uri,
            version: head.version,
            headersNoUpdate: head.headers,
            body: body
        )
        req.isKeepAlive = head.isKeepAlive
        ctx.fireChannelRead(self.wrapInboundOut(req))
    }
}

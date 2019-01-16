/// Private `ChannelInboundHandler` that parses `HTTPClientResponsePart` to `HTTPResponse`.
internal final class HTTPClientResponseDecoder: ChannelInboundHandler {
    typealias InboundIn = HTTPClientResponsePart
    typealias OutboundOut = HTTPResponse
    
    /// Tracks `HTTPClientHandler`'s state.
    enum ResponseState {
        /// Waiting to parse the next response.
        case ready
        /// Currently parsing the response's body.
        case parsingBody(HTTPResponseHead, ByteBuffer?)
    }
    
    var state: ResponseState
    
    init() {
        self.state = .ready
    }
    
    /// See `ChannelInboundHandler`.
    func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
        switch unwrapInboundIn(data) {
        case .head(let head):
            switch self.state {
            case .ready: self.state = .parsingBody(head, nil)
            case .parsingBody: assert(false, "Unexpected HTTPClientResponsePart.head when body was being parsed.")
            }
        case .body(var body):
            switch self.state {
            case .ready: assert(false, "Unexpected HTTPClientResponsePart.body when awaiting request head.")
            case .parsingBody(let head, let existingData):
                let buffer: ByteBuffer
                if var existing = existingData {
                    existing.write(buffer: &body)
                    buffer = existing
                } else {
                    buffer = body
                }
                self.state = .parsingBody(head, buffer)
            }
        case .end(let tailHeaders):
            assert(tailHeaders == nil, "Unexpected tail headers")
            switch self.state {
            case .ready: assert(false, "Unexpected HTTPClientResponsePart.end when awaiting request head.")
            case .parsingBody(let head, let data):
                let body: HTTPBody = data.flatMap { HTTPBody(buffer: $0) } ?? .init()
                let res = HTTPResponse(
                    status: head.status,
                    version: head.version,
                    headersNoUpdate: head.headers,
                    body: body
                )
                self.state = .ready
                ctx.fireChannelRead(wrapOutboundOut(res))
            }
        }
    }
}

final class HTTPServerResponseEncoder: ChannelOutboundHandler {
    typealias OutboundIn = HTTPResponse
    typealias OutboundOut = HTTPServerResponsePart
    
    /// Optional server header.
    private let serverHeader: String?
    
    init(serverHeader: String?) {
        self.serverHeader = serverHeader
    }
    
    func write(ctx: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        var res = self.unwrapOutboundIn(data)
        // add a RFC1123 timestamp to the Date header to make this
        // a valid request
        res.headers.add(name: "date", value: RFC1123DateCache.shared.currentTimestamp())
        
        if let server = self.serverHeader {
            res.headers.add(name: "server", value: server)
        }
        
        // begin serializing
        ctx.write(wrapOutboundOut(.head(.init(
            version: res.version,
            status: res.status,
            headers: res.headers
        ))), promise: nil)
        
        if res.status == .noContent {
            // don't send bodies for 204 (no content) requests
            ctx.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: promise)
        } else {
            switch res.body.storage {
            case .none:
                ctx.writeAndFlush(wrapOutboundOut(.end(nil)), promise: promise)
            case .buffer(let buffer):
                self.writeAndflush(buffer: buffer, ctx: ctx, promise: promise)
            case .string(let string):
                var buffer = ctx.channel.allocator.buffer(capacity: string.count)
                buffer.write(string: string)
                self.writeAndflush(buffer: buffer, ctx: ctx, promise: promise)
            case .staticString(let string):
                var buffer = ctx.channel.allocator.buffer(capacity: string.utf8CodeUnitCount)
                buffer.write(staticString: string)
                self.writeAndflush(buffer: buffer, ctx: ctx, promise: promise)
            case .data(let data):
                var buffer = ctx.channel.allocator.buffer(capacity: data.count)
                buffer.write(bytes: data)
                self.writeAndflush(buffer: buffer, ctx: ctx, promise: promise)
            case .dispatchData(let data):
                var buffer = ctx.channel.allocator.buffer(capacity: data.count)
                buffer.write(bytes: data)
                self.writeAndflush(buffer: buffer, ctx: ctx, promise: promise)
            case .chunkedStream(let stream):
                stream.read { result, stream in
                    switch result {
                    case .chunk(let buffer):
                        return ctx.writeAndFlush(self.wrapOutboundOut(.body(.byteBuffer(buffer))))
                    case .end:
                        promise?.succeed(result: ())
                        return ctx.writeAndFlush(self.wrapOutboundOut(.end(nil)))
                    case .error(let error):
                        promise?.fail(error: error)
                        return ctx.writeAndFlush(self.wrapOutboundOut(.end(nil)))
                    }
                }
            }
        }
    }
    
    /// Writes a `ByteBuffer` to the ctx.
    private func writeAndflush(buffer: ByteBuffer, ctx: ChannelHandlerContext, promise: EventLoopPromise<Void>?) {
        if buffer.readableBytes > 0 {
            _ = ctx.write(wrapOutboundOut(.body(.byteBuffer(buffer))))
        }
        ctx.writeAndFlush(wrapOutboundOut(.end(nil)), promise: promise)
    }
    

}

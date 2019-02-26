final class HTTPServerResponseEncoder: ChannelOutboundHandler, RemovableChannelHandler {
    typealias OutboundIn = HTTPResponse
    typealias OutboundOut = HTTPServerResponsePart
    
    /// Optional server header.
    private let serverHeader: String?
    private let dateCache: RFC1123DateCache
    
    init(serverHeader: String?, dateCache: RFC1123DateCache) {
        self.serverHeader = serverHeader
        self.dateCache = dateCache
    }
    
    func write(ctx: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        var res = self.unwrapOutboundIn(data)
        // add a RFC1123 timestamp to the Date header to make this
        // a valid request
        res.headers.add(name: "date", value: self.dateCache.currentTimestamp())
        
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
                buffer.writeString(string)
                self.writeAndflush(buffer: buffer, ctx: ctx, promise: promise)
            case .staticString(let string):
                var buffer = ctx.channel.allocator.buffer(capacity: string.utf8CodeUnitCount)
                buffer.writeStaticString(string)
                self.writeAndflush(buffer: buffer, ctx: ctx, promise: promise)
            case .data(let data):
                var buffer = ctx.channel.allocator.buffer(capacity: data.count)
                #warning("TODO: use nio foundation compat")
                buffer.writeBytes(data)
                self.writeAndflush(buffer: buffer, ctx: ctx, promise: promise)
            case .dispatchData(let data):
                var buffer = ctx.channel.allocator.buffer(capacity: data.count)
                buffer.writeDispatchData(data)
                self.writeAndflush(buffer: buffer, ctx: ctx, promise: promise)
            case .stream(let stream):
                stream.read { result, stream in
                    switch result {
                    case .chunk(let buffer):
                        ctx.writeAndFlush(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
                    case .end:
                        promise?.succeed(())
                        ctx.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
                    case .error(let error):
                        promise?.fail(error)
                        ctx.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
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

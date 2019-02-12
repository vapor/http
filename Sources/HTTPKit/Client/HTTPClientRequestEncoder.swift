/// Private `ChannelOutboundHandler` that serializes `HTTPRequest` to `HTTPClientRequestPart`.
internal final class HTTPClientRequestEncoder: ChannelOutboundHandler, RemovableChannelHandler {
    typealias OutboundIn = HTTPRequest
    typealias OutboundOut = HTTPClientRequestPart

    let hostname: String
    
    /// Creates a new `HTTPClientRequestSerializer`.
    init(hostname: String) {
        self.hostname = hostname
    }
    
    /// See `ChannelOutboundHandler`.
    func write(ctx: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let req = unwrapOutboundIn(data)
        var headers = req.headers
        headers.add(name: .host, value: self.hostname)
        
        let path: String
        if let query = req.url.query {
            path = req.url.path + "?" + query
        } else {
            path = req.url.path
        }
        
        headers.replaceOrAdd(name: .userAgent, value: "Vapor/4.0 (Swift)")
        var httpHead = HTTPRequestHead(
            version: req.version,
            method: req.method,
            uri: path.hasPrefix("/") ? path : "/" + path
        )
        httpHead.headers = headers
        ctx.write(wrapOutboundOut(.head(httpHead)), promise: nil)
        if let data = req.body.data {
            var buffer = ByteBufferAllocator().buffer(capacity: data.count)
            buffer.writeBytes(data)
            ctx.write(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        }
        ctx.write(self.wrapOutboundOut(.end(nil)), promise: promise)
    }
}

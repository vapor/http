/// Private `ChannelOutboundHandler` that serializes `HTTPRequest` to `HTTPClientRequestPart`.
internal final class HTTPClientRequestEncoder: ChannelOutboundHandler, RemovableChannelHandler {
    typealias OutboundIn = HTTPRequest
    typealias OutboundOut = HTTPClientRequestPart

    let host: String
    
    /// Creates a new `HTTPClientRequestSerializer`.
    init(host: String) {
        self.host = host
    }
    
    /// See `ChannelOutboundHandler`.
    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let req = unwrapOutboundIn(data)
        var headers = req.headers
        headers.add(name: .host, value: self.host)
        
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
        context.write(wrapOutboundOut(.head(httpHead)), promise: nil)
        if let data = req.body.data {
            var buffer = ByteBufferAllocator().buffer(capacity: data.count)
            buffer.writeBytes(data)
            context.write(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        }
        context.write(self.wrapOutboundOut(.end(nil)), promise: promise)
    }
}

internal final class HTTPClientHandler: ChannelDuplexHandler {
    typealias InboundIn = HTTPResponse
    typealias OutboundIn = HTTPClientRequestContext
    typealias OutboundOut = HTTPRequest
    
    private var queue: [HTTPClientRequestContext]
    
    init() {
        self.queue = []
    }
    
    func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
        let res = self.unwrapInboundIn(data)
        self.queue[0].promise.succeed(result: res)
        self.queue.removeFirst()
    }
    
    func write(ctx: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let req = self.unwrapOutboundIn(data)
        self.queue.append(req)
        ctx.write(self.wrapOutboundOut(req.request), promise: nil)
        ctx.flush()
    }
    
    func errorCaught(ctx: ChannelHandlerContext, error: Error) {
        switch self.queue.count {
        case 0:
            ctx.fireErrorCaught(error)
        default:
            self.queue.removeFirst().promise.fail(error: error)
        }
    }
}

internal final class HTTPClientRequestContext {
    let request: HTTPRequest
    let promise: EventLoopPromise<HTTPResponse>
    
    init(request: HTTPRequest, promise: EventLoopPromise<HTTPResponse>) {
        self.request = request
        self.promise = promise
    }
}

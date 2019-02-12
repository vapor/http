internal final class HTTPClientHandler: ChannelDuplexHandler, RemovableChannelHandler {
    typealias InboundIn = HTTPResponse
    typealias OutboundIn = HTTPClientRequestContext
    typealias OutboundOut = HTTPRequest
    
    private var queue: [HTTPClientRequestContext]
    
    init() {
        self.queue = []
    }
    
    func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
        let res = self.unwrapInboundIn(data)
        self.queue[0].promise.succeed(res)
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
            self.queue.removeFirst().promise.fail(error)
        }
    }
    
    func close(ctx: ChannelHandlerContext, mode: CloseMode, promise: EventLoopPromise<Void>?) {
        if let promise = promise {
            // we need to do some error mapping here, so create a new promise
            let p = ctx.eventLoop.makePromise(of: Void.self)
            
            // forward the close request with our new promise
            ctx.close(mode: mode, promise: p)
            
            // forward close future results based on whether
            // the close was successful
            p.futureResult.whenSuccess { promise.succeed(()) }
            p.futureResult.whenFailure { error in
                if
                    let sslError = error as? OpenSSLError,
                    case .uncleanShutdown = sslError,
                    self.queue.isEmpty
                {
                    // we can ignore unclear shutdown errors
                    // since no requests are pending
                    //
                    // NOTE: this logic assumes that when self.queue is empty,
                    // all HTTP responses have been completely recieved.
                    // Special attention should be given to this if / when
                    // streaming body support is added.
                    promise.succeed(())
                } else {
                    promise.fail(error)
                }
            }
        } else {
            // no close promise anyway, just forward request
            ctx.close(mode: mode, promise: nil)
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

internal final class HTTPClientHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPResponse
    typealias OutboundOut = HTTPRequest
    
    let promise: EventLoopPromise<HTTPResponse>
    
    init(promise: EventLoopPromise<HTTPResponse>) {
        self.promise = promise
    }
    
    func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
        let res = self.unwrapInboundIn(data)
        promise.succeed(result: res)
    }
    
    func errorCaught(ctx: ChannelHandlerContext, error: Error) {
        promise.fail(error: error)
    }
}

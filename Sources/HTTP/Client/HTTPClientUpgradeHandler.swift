internal final class HTTPClientUpgradeHandler: ChannelDuplexHandler {
    typealias InboundIn = HTTPResponse
    typealias OutboundIn = HTTPRequest
    typealias OutboundOut = HTTPRequest
    
    enum UpgradeState {
        case ready
        case pending(HTTPRequest)
    }

    var state: UpgradeState
    let otherHTTPHandlers: [ChannelHandler]

    init(
        otherHTTPHandlers: [ChannelHandler]
    ) {
        self.otherHTTPHandlers = otherHTTPHandlers
        self.state = .ready
    }

    func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
        switch self.state {
        case .pending(let req):
            let res = unwrapInboundIn(data)
            if res.status == .switchingProtocols, let upgrader = req.upgrader {
                _ = upgrader.upgrade(ctx: ctx, upgradeResponse: .init(
                    version: res.version,
                    status: res.status,
                    headers: res.headers
                )).then { _ in
                    return EventLoopFuture<Void>.andAll(([self] + self.otherHTTPHandlers).map { handler in
                        return ctx.pipeline.remove(handler: handler).map { _ in Void() }
                    }, eventLoop: ctx.eventLoop)
                }
            } else {
                ctx.fireChannelRead(data)
            }
        case .ready:
            ctx.fireChannelRead(data)
        }
    }
    
    func write(ctx: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let req = self.unwrapOutboundIn(data)
        if req.upgrader != nil {
            self.state = .pending(req)
        }
        ctx.write(self.wrapOutboundOut(req), promise: promise)
    }
}

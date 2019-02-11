internal final class HTTPClientUpgradeHandler: ChannelDuplexHandler {
    typealias InboundIn = HTTPResponse
    typealias OutboundIn = HTTPRequest
    typealias OutboundOut = HTTPRequest
    
    enum UpgradeState {
        case ready
        case pending(HTTPClientProtocolUpgrader)
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
        ctx.fireChannelRead(data)
        
        switch self.state {
        case .pending(let upgrader):
            let res = self.unwrapInboundIn(data)
            if res.status == .switchingProtocols {
                ctx.pipeline.remove(handler: self, promise: nil)
                self.otherHTTPHandlers.forEach { ctx.pipeline.remove(handler: $0, promise: nil) }
                upgrader.upgrade(ctx: ctx, upgradeResponse: .init(
                    version: res.version,
                    status: res.status,
                    headers: res.headers
                )).whenFailure { error in
                    self.errorCaught(ctx: ctx, error: error)
                }
            }
        case .ready: break
        }
    }
    
    func write(ctx: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        var req = self.unwrapOutboundIn(data)
        if let upgrader = req.upgrader {
            for (name, value) in upgrader.buildUpgradeRequest() {
                req.headers.add(name: name, value: value)
            }
            self.state = .pending(upgrader)
        }
        ctx.write(self.wrapOutboundOut(req), promise: promise)
    }
}

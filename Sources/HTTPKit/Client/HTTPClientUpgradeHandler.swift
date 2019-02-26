internal final class HTTPClientUpgradeHandler: ChannelDuplexHandler, RemovableChannelHandler {
    typealias InboundIn = HTTPResponse
    typealias OutboundIn = HTTPRequest
    typealias OutboundOut = HTTPRequest
    
    enum UpgradeState {
        case ready
        case pending(HTTPClientProtocolUpgrader)
    }

    var state: UpgradeState
    let otherHTTPHandlers: [RemovableChannelHandler]

    init(
        otherHTTPHandlers: [RemovableChannelHandler]
    ) {
        self.otherHTTPHandlers = otherHTTPHandlers
        self.state = .ready
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        context.fireChannelRead(data)
        switch self.state {
        case .pending(let upgrader):
            let res = self.unwrapInboundIn(data)
            if res.status == .switchingProtocols {
                context.pipeline.removeHandler(self, promise: nil)
                self.otherHTTPHandlers.forEach { context.pipeline.removeHandler($0, promise: nil) }
                upgrader.upgrade(context: context, upgradeResponse: .init(
                    version: res.version,
                    status: res.status,
                    headers: res.headers
                )).whenFailure { error in
                    self.errorCaught(context: context, error: error)
                }
            }
        case .ready: break
        }
    }
    
    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        var req = self.unwrapOutboundIn(data)
        if let upgrader = req.upgrader {
            for (name, value) in upgrader.buildUpgradeRequest() {
                req.headers.add(name: name, value: value)
            }
            self.state = .pending(upgrader)
        }
        context.write(self.wrapOutboundOut(req), promise: promise)
    }
}

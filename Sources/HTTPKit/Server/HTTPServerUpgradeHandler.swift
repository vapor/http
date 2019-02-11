final class HTTPServerUpgradeHandler: ChannelDuplexHandler {
    typealias InboundIn = HTTPRequest
    typealias OutboundIn = HTTPResponse
    typealias OutboundOut = HTTPResponse
    
    
    private enum UpgradeState {
        case ready
        case pending(HTTPRequest, UpgradeBufferHandler)
        case upgraded
    }
    
    
    private var upgradeState: UpgradeState
    let httpRequestDecoder: HTTPRequestDecoder
    let otherHTTPHandlers: [ChannelHandler]
    
    init(
        httpRequestDecoder: HTTPRequestDecoder,
        otherHTTPHandlers: [ChannelHandler]
    ) {
        self.upgradeState = .ready
        self.httpRequestDecoder = httpRequestDecoder
        self.otherHTTPHandlers = otherHTTPHandlers
    }
    
    func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
        let req = self.unwrapInboundIn(data)
        
        // check if request is upgrade
        let connectionHeaders = Set(req.headers[canonicalForm: "connection"].map { $0.lowercased() })
        if connectionHeaders.contains("upgrade") {
            // remove http decoder
            let buffer = UpgradeBufferHandler()
            _ = ctx.channel.pipeline.add(handler: buffer, after: self.httpRequestDecoder).flatMap {
                return ctx.channel.pipeline.remove(handler: self.httpRequestDecoder)
            }
            self.upgradeState = .pending(req, buffer)
        }
        
        ctx.fireChannelRead(data)
    }
    
    func write(ctx: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let res = self.unwrapOutboundIn(data)
        
        ctx.write(self.wrapOutboundOut(res), promise: promise)
        
        // check upgrade
        switch self.upgradeState {
        case .pending(let req, let buffer):
            if res.status == .switchingProtocols, let upgrader = res.upgrader {
                // do upgrade
                _ = EventLoopFuture<Void>.andAllComplete(([self] + self.otherHTTPHandlers).map { handler in
                    return ctx.pipeline.remove(handler: handler).map { _ in Void() }
                }, on: ctx.eventLoop).flatMap { _ in
                    return upgrader.upgrade(
                        ctx: ctx,
                        upgradeRequest: .init(
                            version: req.version,
                            method: req.method,
                            uri: req.urlString
                        )
                    )
                }.flatMap {
                    return ctx.pipeline.remove(handler: buffer)
                }
                self.upgradeState = .upgraded
            } else {
                // reset handlers
                self.upgradeState = .ready
                _ = ctx.channel.pipeline.add(handler: self.httpRequestDecoder, after: buffer).flatMap {
                    return ctx.channel.pipeline.remove(handler: buffer)
                }
            }
        case .ready: break
        case .upgraded: break
        }
    }
}

private final class UpgradeBufferHandler: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer
    
    var buffer: [ByteBuffer]
    
    init() {
        self.buffer = []
    }
    
    func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
        let data = self.unwrapInboundIn(data)
        self.buffer.append(data)
    }
    
    func handlerRemoved(ctx: ChannelHandlerContext) {
        for data in self.buffer {
            ctx.fireChannelRead(NIOAny(data))
        }
    }
}

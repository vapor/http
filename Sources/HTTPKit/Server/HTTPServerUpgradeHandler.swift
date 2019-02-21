final class HTTPServerUpgradeHandler: ChannelDuplexHandler, RemovableChannelHandler {
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
    let otherHTTPHandlers: [RemovableChannelHandler]
    
    init(
        httpRequestDecoder: HTTPRequestDecoder,
        otherHTTPHandlers: [RemovableChannelHandler]
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
            _ = ctx.channel.pipeline.addHandler(buffer, position: .after(self.httpRequestDecoder)).flatMap {
                return ctx.channel.pipeline.removeHandler(self.httpRequestDecoder)
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
                let handlers: [RemovableChannelHandler] = [self] + self.otherHTTPHandlers
                _ = EventLoopFuture<Void>.andAllComplete(handlers.map { handler in
                    return ctx.pipeline.removeHandler(handler)
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
                    return ctx.pipeline.removeHandler(buffer)
                }
                self.upgradeState = .upgraded
            } else {
                // reset handlers
                self.upgradeState = .ready
                _ = ctx.channel.pipeline.addHandler(self.httpRequestDecoder, position: .after(buffer)).flatMap {
                    return ctx.channel.pipeline.removeHandler(buffer)
                }
            }
        case .ready: break
        case .upgraded: break
        }
    }
}

private final class UpgradeBufferHandler: ChannelInboundHandler, RemovableChannelHandler {
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

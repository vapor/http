final class HTTPClientProxyHandler: ChannelDuplexHandler {
    typealias InboundIn = HTTPClientResponsePart
    typealias OutboundIn = HTTPClientRequestPart
    typealias OutboundOut = HTTPClientRequestPart
    
    let hostname: String
    let port: Int
    var onConnect: (ChannelHandlerContext) -> ()
    
    private var buffer: [HTTPClientRequestPart]
    
    
    init(hostname: String, port: Int, onConnect: @escaping (ChannelHandlerContext) -> ()) {
        self.hostname = hostname
        self.port = port
        self.onConnect = onConnect
        self.buffer = []
    }
    
    func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
        let res = self.unwrapInboundIn(data)
        switch res {
        case .head(let head):
            assert(head.status == .ok)
        case .end:
            self.configureTLS(ctx: ctx)
        default: assertionFailure("invalid state: \(res)")
        }
    }
    
    func write(ctx: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let req = self.unwrapOutboundIn(data)
        self.buffer.append(req)
        promise?.succeed(result: ())
    }
    
    func channelActive(ctx: ChannelHandlerContext) {
        self.sendConnect(ctx: ctx)
    }
    
    // MARK: Private
    
    private func configureTLS(ctx: ChannelHandlerContext) {
        self.onConnect(ctx)
        self.buffer.forEach { ctx.write(self.wrapOutboundOut($0), promise: nil) }
        ctx.flush()
        _ = ctx.pipeline.remove(handler: self)
    }
    
    private func sendConnect(ctx: ChannelHandlerContext) {
        var head = HTTPRequestHead(
            version: .init(major: 1, minor: 1),
            method: .CONNECT,
            uri: "\(self.hostname):\(self.port)"
        )
        head.headers.add(name: "proxy-connection", value: "keep-alive")
        ctx.write(self.wrapOutboundOut(.head(head)), promise: nil)
        ctx.write(self.wrapOutboundOut(.end(nil)), promise: nil)
        ctx.flush()
    }
}

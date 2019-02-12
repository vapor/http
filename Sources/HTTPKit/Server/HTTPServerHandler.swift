// import Logging

final class HTTPServerHandler: ChannelInboundHandler, RemovableChannelHandler {
    typealias InboundIn = HTTPRequest
    typealias OutboundOut = HTTPResponse
    
    let delegate: HTTPServerDelegate
    let errorHandler: (Error) -> ()
    
    init(
        delegate: HTTPServerDelegate,
        errorHandler: @escaping (Error) -> ()
    ) {
        self.delegate = delegate
        self.errorHandler = errorHandler
    }
    
    func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
        var req = self.unwrapInboundIn(data)

        // change HEAD -> GET
        let originalMethod = req.method
        switch req.method {
        case .HEAD: req.method = .GET
        default: break
        }
        
        // query delegate for response
        self.delegate.respond(to: req, on: ctx.channel).whenComplete { res in
            switch res {
            case .failure(let error):
                self.errorHandler(error)
                ctx.close(promise: nil)
            case .success(var res):
                if originalMethod == .HEAD {
                    res.body = .init()
                }
                self.serialize(res, for: req, ctx: ctx)
            }
        }
    }
    
    func serialize(_ res: HTTPResponse, for req: HTTPRequest, ctx: ChannelHandlerContext) {
        switch req.body.storage {
        case .chunkedStream(let stream):
            assert(stream.isClosed, "HTTPResponse sent while HTTPRequest had unconsumed chunked data.")
        default: break
        }
        
        var res = res
        res.headers.add(name: .connection, value: req.isKeepAlive ? "keep-alive" : "close")
        let done = ctx.write(self.wrapOutboundOut(res))
        
        if !req.isKeepAlive {
            _ = done.flatMap {
                return ctx.close()
            }
        }
    }
}

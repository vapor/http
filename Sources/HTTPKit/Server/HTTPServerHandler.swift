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
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var req = self.unwrapInboundIn(data)

        // change HEAD -> GET
        let originalMethod = req.method
        switch req.method {
        case .HEAD: req.method = .GET
        default: break
        }
        
        // query delegate for response
        self.delegate.respond(to: req, on: context.channel).whenComplete { res in
            switch res {
            case .failure(let error):
                self.errorHandler(error)
                context.close(promise: nil)
            case .success(var res):
                if originalMethod == .HEAD {
                    res.body = .init()
                }
                self.serialize(res, for: req, context: context)
            }
        }
    }
    
    func serialize(_ res: HTTPResponse, for req: HTTPRequest, context: ChannelHandlerContext) {
        switch req.body.storage {
        case .stream(let stream):
            assert(stream.isClosed, "HTTPResponse sent while HTTPRequest had unconsumed chunked data.")
        default: break
        }
        
        switch req.version.major {
        case 2:
            context.write(self.wrapOutboundOut(res), promise: nil)
        default:
            var res = res
            res.headers.add(name: .connection, value: req.isKeepAlive ? "keep-alive" : "close")
            let done = context.write(self.wrapOutboundOut(res))
            if !req.isKeepAlive {
                _ = done.flatMap {
                    return context.close()
                }
            }
        }
    }
}

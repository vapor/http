import Foundation

/// Simple HTTP server generic on an HTTP responder
/// that will be used to generate responses to incoming requests.
public final class HTTPServer<Responder> where Responder: HTTPResponder {
    /// The responder generating `HTTPResponse`s for incoming `HTTPRequest`s.
    public let responder: Responder

    /// Create a new `HTTPServer` using the supplied `HTTPResponder`
    public init(responder: Responder) {
        self.responder = responder
    }

    /// Starts the server on the supplied hostname and port.
    public func start(hostname: String, port: Int) -> Future<Void> {
        let group = MultiThreadedEventLoopGroup(numThreads: 1) // System.coreCount
        let bootstrap = ServerBootstrap(group: group)
            // Specify backlog and enable SO_REUSEADDR for the server itself
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)

            // Set the handlers that are applied to the accepted Channels
            .childChannelInitializer { channel in
                // re-use subcontainer for an event loop here
                return channel.pipeline.addHTTPServerHandlers().then {
                    channel.pipeline.add(handler: HTTPServerHandler(self.responder))
                }
            }

            // Enable TCP_NODELAY and SO_REUSEADDR for the accepted Channels
            .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
            .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)

        return bootstrap.bind(host: hostname, port: port).flatMap(to: Void.self) { channel in
            return channel.closeFuture
        }
    }
}

/// MARK: Handler

enum HTTPServerState {
    case ready
    case parsingBody(HTTPRequestHead, Data?)
}

final class HTTPServerHandler<Responder>: ChannelInboundHandler where Responder: HTTPResponder {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    let responder: Responder
    var state: HTTPServerState

    init(_ responder: Responder) {
        self.responder = responder
        self.state = .ready
    }

    func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
        assert(ctx.channel.eventLoop.inEventLoop)
        let req = unwrapInboundIn(data)
        switch req {
        case .head(let head):
            switch state {
            case .ready: state = .parsingBody(head, nil)
            case .parsingBody: fatalError()
            }
        case .body(var body):
            switch state {
            case .ready: fatalError()
            case .parsingBody(let head, let existingData):
                let data: Data
                if var existing = existingData {
                    existing += body.readData(length: body.readableBytes) ?? Data()
                    data = existing
                } else {
                    data = body.readData(length: body.readableBytes) ?? Data()
                }
                state = .parsingBody(head, data)
            }
        case .end(let tailHeaders):
            assert(tailHeaders == nil)
            switch state {
            case .ready: fatalError()
            case .parsingBody(let head, let data):
                let req = HTTPRequest(
                    method: head.method,
                    url: URL(string: head.uri)!,
                    version: head.version,
                    headers: head.headers,
                    body: data.flatMap { HTTPBody(data: $0) },
                    on: wrap(ctx.eventLoop)
                )
                responder.respond(to: req).do { res in
                    var headers = res.headers
                    if let contentLength = res.body?.count {
                        headers.replaceOrAdd(name: .contentLength, value: contentLength.description)
                    }
                    let httpHead = HTTPResponseHead(version: res.version, status: res.status, headers: headers)
                    ctx.write(self.wrapOutboundOut(.head(httpHead)), promise: nil)
                    if let body = res.body, let data = body.data {
                        var buffer = ByteBufferAllocator().buffer(capacity: data.count)
                        buffer.write(bytes: data)
                        ctx.write(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
                    }
                    ctx.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
                }.catch { error in
                    fatalError("\(error)")
                }
            }
        }
    }

    func channelReadComplete(ctx: ChannelHandlerContext) { }
    func handlerAdded(ctx: ChannelHandlerContext) { }
}


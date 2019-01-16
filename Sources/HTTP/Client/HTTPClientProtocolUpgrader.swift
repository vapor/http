import NIO
import NIOHTTP1

//extension HTTPClient {
//    // MARK: Upgrade
//
//    /// Performs an HTTP protocol upgrade connected using the `HTTPClient`.
//    ///
//    ///     let webSocketUpgrader: ...
//    ///     let webSocket = try HTTPClient.upgrade(hostname: "vapor.codes", upgrader: webSocketUpgrader, on: req).wait()
//    ///
//    /// - parameters:
//    ///     - scheme: Transport layer security to use, either `http` or `https`.
//    ///     - hostname: Remote server's hostname.
//    ///     - port: Remote server's port, defaults to 80 for TCP and 443 for TLS.
//    ///     - worker: `Worker` to perform async work on.
//    /// - returns: A `Future` containing the upgrade result.
//    public static func upgrade<Upgrader>(
//        scheme: HTTPScheme = .http,
//        hostname: String,
//        port: Int? = nil,
//        upgrader: Upgrader,
//        on eventLoop: EventLoop
//    ) -> EventLoopFuture<Upgrader.UpgradeResult> where Upgrader: HTTPClientProtocolUpgrader {
//        let handler = HTTPClientUpgradeHandler(upgrader: upgrader, extraHTTPHandlerNames: ["HTTPRequestEncoder", "HTTPResponseDecoder"], on: eventLoop)
//        let bootstrap = ClientBootstrap(group: eventLoop)
//            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
//            .channelInitializer { channel in
//                return scheme.configureChannel(channel).then { _ in
//                    return channel.pipeline.add(name: "HTTPRequestEncoder", handler: HTTPRequestEncoder(), first: false).then { _ in
//                        return channel.pipeline.add(name: "HTTPResponseDecoder", handler: HTTPResponseDecoder(), first: false).then { _ in
//                            return channel.pipeline.add(handler: handler, first: false)
//                        }
//                    }
//                }
//        }
//
//        bootstrap.connect(
//            host: hostname,
//            port: port ?? scheme.defaultPort
//        ).cascadeFailure(promise: handler.upgradePromise)
//
//        return handler.onUpgrade
//    }
//}

/// Can be used to upgrade `HTTPClient` requests using the static `HTTPClient.upgrade(...)` method.
public protocol HTTPClientProtocolUpgrader {
    /// Builds the `HTTPHeaders` required for an upgrade.
    func buildUpgradeRequest() -> HTTPHeaders

    /// Returns `true` if the `HTTPResponseHead` is valid. If `false`,
    /// the upgrade will be aborted.
    func isValidUpgradeResponse(_ upgradeResponse: HTTPResponseHead) -> Bool

    /// Called if `isValidUpgradeResponse` returns `true`. This should return the `UpgradeResult`
    /// that will ultimately be returned by `HTTPClient.upgrade(...)`.
    func upgrade(ctx: ChannelHandlerContext, upgradeResponse: HTTPResponseHead) -> EventLoopFuture<Void>
}

// MARK: Private

///// Private `ChannelInboundHandler` for performing the upgrade.
//private final class HTTPClientUpgradeHandler<Upgrader>: ChannelInboundHandler where Upgrader: HTTPClientProtocolUpgrader {
//    /// See `ChannelInboundHandler`.
//    typealias InboundIn = HTTPClientResponsePart
//
//    /// See `ChannelInboundHandler`.
//    typealias InboundOut = HTTPClientResponsePart
//
//    /// See `ChannelInboundHandler`.
//    typealias OutboundOut = HTTPClientRequestPart
//
//    /// The `HTTPClientProtocolUpgrader` powering this upgrade handler.
//    private let upgrader: Upgrader
//
//    /// References to extraneous handlers that should be removed once the upgrade completes.
//    private let extraHTTPHandlerNames: [String]
//
//    /// If `true`, we are currently upgrading.
//    private var upgrading: Bool
//
//    /// If `true`, the first `HTTPResponse` has already been seen.
//    private var seenFirstResponse: Bool
//
//    /// Used to backlog messages while upgrading.
//    private var receivedMessages: [NIOAny]
//
//    /// Will be fulfilled with the upgrade result when the upgrade completes.
//    var upgradePromise: EventLoopPromise<Void>
//
//    /// Internal future to use for awaiting the upgrade result.
//    var onUpgrade: EventLoopFuture<Void> {
//        return upgradePromise.futureResult
//    }
//
//    /// Creates a new `HTTPClientUpgradeHandler`.
//    init(upgrader: Upgrader, extraHTTPHandlerNames: [String], on eventLoop: EventLoop) {
//        self.upgrader = upgrader
//        self.extraHTTPHandlerNames = extraHTTPHandlerNames
//        self.upgrading = false
//        self.receivedMessages = []
//        self.seenFirstResponse = false
//        self.upgradePromise = eventLoop.makePromise(of: Void.self)
//    }
//
//    /// See `ChannelInboundHandler`.
//    func channelActive(ctx: ChannelHandlerContext) {
//        ctx.write(wrapOutboundOut(.head(upgrader.buildUpgradeRequest())), promise: nil)
//        ctx.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
//    }
//
//    /// See `ChannelInboundHandler`.
//    func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
//        if upgrading {
//            // We're waiting for upgrade to complete: buffer this data.
//            receivedMessages.append(data)
//            return
//        }
//
//        // We're trying to remove ourselves from the pipeline but not upgrading, so just pass this on.
//        if seenFirstResponse {
//            ctx.fireChannelRead(data)
//            return
//        }
//
//        let responsePart = unwrapInboundIn(data)
//        seenFirstResponse = true
//
//        // We should only ever see a request header: by the time the body comes in we should
//        // be out of the pipeline. Anything else is an error.
//        guard case .head(let res) = responsePart, res.status == .switchingProtocols, upgrader.isValidUpgradeResponse(res) else {
//            notUpgrading(ctx: ctx, data: data)
//            return
//        }
//
//        upgrading = true
//        removeExtraHandlers(ctx: ctx).then {
//            return ctx.pipeline.remove(ctx: ctx)
//        }.then { _ in
//            return self.upgrader.upgrade(ctx: ctx, upgradeResponse: res)
//        }.cascade(promise: upgradePromise)
//    }
//
//    /// Called when we know we're not upgrading. Passes the data on and then removes this object from the pipeline.
//    private func notUpgrading(ctx: ChannelHandlerContext, data: NIOAny) {
//        assert(self.receivedMessages.count == 0)
//        ctx.fireChannelRead(data)
//        _ = ctx.pipeline.remove(ctx: ctx)
//        self.upgradePromise.fail(error: HTTPError(identifier: "notUpgrading", reason: "Did not recieve a valid upgrade response."))
//    }
//
//    /// Removes any extra HTTP-related handlers from the channel pipeline.
//    private func removeExtraHandlers(ctx: ChannelHandlerContext) -> EventLoopFuture<Void> {
//        guard self.extraHTTPHandlerNames.count > 0 else {
//            return ctx.eventLoop.makeSucceededFuture(result: ())
//        }
//        return .andAll(self.extraHTTPHandlerNames.map {
//            ctx.pipeline.remove(name: $0).map { _ in Void() }
//        }, eventLoop: ctx.eventLoop)
//    }
//}

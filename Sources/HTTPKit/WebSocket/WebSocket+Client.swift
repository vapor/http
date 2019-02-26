import Foundation

extension HTTPRequest {
    #warning("TODO: consider making non-static")
    public static func webSocketUpgrade(
        method: HTTPMethod = .GET,
        url: URLRepresentable = URL.root,
        version: HTTPVersion = .init(major: 1, minor: 1),
        headers: HTTPHeaders = .init(),
        body: LosslessHTTPBodyRepresentable = HTTPBody(),
        onUpgrade: @escaping (WebSocket) -> ()
    ) throws -> HTTPRequest {
        var req = HTTPRequest(method: method, url: url, version: version, headers: headers, body: body)
        let upgrader = WebSocketClientUpgrader(upgradePipelineHandler: { channel, res in
            let webSocket = WebSocket(channel: channel, mode: .client)
            onUpgrade(webSocket)
            return channel.pipeline.add(webSocket: webSocket)
        })
        for (name, value) in upgrader.buildUpgradeRequest() {
            req.headers.add(name: name, value: value)
        }
        req.upgrader = upgrader
        return req
    }
}

/// Allows `HTTPClient` to be used to create `WebSocket` connections.
///
///     let ws = try HTTPClient.webSocket(hostname: "echo.websocket.org", on: ...).wait()
///     ws.onText { ws, text in
///         print("server said: \(text)")
///     }
///     ws.send("Hello, world!")
///     try ws.onClose.wait()
///
//extension HTTPClient {
//    // MARK: Client Upgrade
//
//    /// Performs an HTTP protocol upgrade to` WebSocket` protocol `HTTPClient`.
//    ///
//    ///     let ws = try HTTPClient.webSocket(hostname: "echo.websocket.org", on: ...).wait()
//    ///     ws.onText { ws, text in
//    ///         print("server said: \(text)")
//    ///     }
//    ///     ws.send("Hello, world!")
//    ///     try ws.onClose.wait()
//    ///
//    /// - parameters:
//    ///     - scheme: Transport layer security to use, either tls or plainText.
//    ///     - hostname: Remote server's hostname.
//    ///     - port: Remote server's port, defaults to 80 for TCP and 443 for TLS.
//    ///     - path: Path on remote server to connect to.
//    ///     - headers: Additional HTTP headers are used to establish a connection.
//    ///     - maxFrameSize: Maximum WebSocket frame size this client will accept.
//    ///     - worker: `Worker` to perform async work on.
//    /// - returns: A `Future` containing the connected `WebSocket`.
//    public static func webSocket(
//        scheme: HTTPScheme = .ws,
//        hostname: String,
//        port: Int? = nil,
//        path: String = "/",
//        headers: HTTPHeaders = .init(),
//        maxFrameSize: Int = 1 << 14,
//        on eventLoop: EventLoop
//    ) -> EventLoopFuture<WebSocket> {
//        let upgrader = WebSocketClientUpgrader(hostname: hostname, path: path, headers: headers, maxFrameSize: maxFrameSize)
//        return HTTPClient.upgrade(scheme: scheme, hostname: hostname, port: port, upgrader: upgrader, on: eventLoop)
//    }
//}

// MARK: Private

/// Private `HTTPClientProtocolUpgrader` for use with `HTTPClient.upgrade(...)`.
public final class WebSocketClientUpgrader: HTTPClientProtocolUpgrader {
    /// Maximum frame size for decoder.
    private let maxFrameSize: Int
    
    private let upgradePipelineHandler: (Channel, HTTPResponseHead) -> EventLoopFuture<Void>

    /// Creates a new `WebSocketClientUpgrader`.
    public init(
        maxFrameSize: Int = 1 << 14,
        upgradePipelineHandler: @escaping (Channel, HTTPResponseHead) -> EventLoopFuture<Void>
    ) {
        self.maxFrameSize = maxFrameSize
        self.upgradePipelineHandler = upgradePipelineHandler
    }

    /// See `HTTPClientProtocolUpgrader`.
    public func buildUpgradeRequest() -> HTTPHeaders {
        var headers = HTTPHeaders()
        headers.add(name: .connection, value: "Upgrade")
        headers.add(name: .upgrade, value: "websocket")
        headers.add(name: .origin, value: "vapor/websocket")
        headers.add(name: .secWebSocketVersion, value: "13")
        let bytes: [UInt8]  = [
            .anyRandom, .anyRandom, .anyRandom, .anyRandom,
            .anyRandom, .anyRandom, .anyRandom, .anyRandom,
            .anyRandom, .anyRandom, .anyRandom, .anyRandom,
            .anyRandom, .anyRandom, .anyRandom, .anyRandom
        ]
        headers.add(name: .secWebSocketKey, value: Data(bytes).base64EncodedString())
        return headers
    }

    /// See `HTTPClientProtocolUpgrader`.
    public func upgrade(context: ChannelHandlerContext, upgradeResponse: HTTPResponseHead) -> EventLoopFuture<Void> {
        return context.channel.pipeline.addHandlers([
            WebSocketFrameEncoder(),
            ByteToMessageHandler(WebSocketFrameDecoder(maxFrameSize: maxFrameSize))
        ], position: .first).flatMap {
            self.upgradePipelineHandler(context.channel, upgradeResponse)
        }
    }
}

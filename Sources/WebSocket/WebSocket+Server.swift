extension HTTPResponse {
    #warning("TODO: consider making non-static")
    public static func webSocketUpgrade(
        headers: HTTPHeaders = [:],
        for req: HTTPRequest,
        onUpgrade: @escaping (WebSocket) -> ()
    ) throws -> HTTPResponse {
        let connectionHeaders = Set(req.headers[canonicalForm: "connection"].map { $0.lowercased() })
        let upgradeHeaders = Set(req.headers[canonicalForm: "upgrade"].map { $0.lowercased() })
        
        if connectionHeaders.contains("upgrade"), upgradeHeaders.contains("websocket") {
            let upgrader = WebSocketUpgrader(shouldUpgrade: { _ in
                return headers
            }, upgradePipelineHandler: { channel, req in
                let webSocket = WebSocket(channel: channel, mode: .server)
                onUpgrade(webSocket)
                return channel.pipeline.add(webSocket: webSocket)
            })
            
            var head = HTTPRequestHead(
                version: req.version,
                method: req.method,
                uri: req.urlString
            )
            head.headers = req.headers
            let headers = try upgrader.buildUpgradeResponse(
                upgradeRequest: head,
                initialResponseHeaders: .init()
            )
            var res = HTTPResponse(status: .switchingProtocols, headers: headers)
            res.upgrader = upgrader
            return res
        } else {
            #warning("TODO: throw HTTP upgrade failed")
            fatalError()
        }
    }
}
/// Allows `HTTPServer` to accept `WebSocket` connections.
///
///     let ws = HTTPServer.webSocketUpgrader(shouldUpgrade: { req in
///         // return non-nil HTTPHeaders to allow upgrade
///     }, onUpgrade: { ws, req in
///         // setup callbacks or send data to connected WebSocket
///     })
///
///     HTTPServer.start(..., upgraders: [ws])
///
extension HTTPServer {
    // MARK: Server Upgrade

    /// Creates an `HTTPProtocolUpgrader` that will accept incoming `WebSocket` upgrade requests.
    ///
    ///     let ws = HTTPServer.webSocketUpgrader(shouldUpgrade: { req in
    ///         // return non-nil HTTPHeaders to allow upgrade
    ///     }, onUpgrade: { ws, req in
    ///         // setup callbacks or send data to connected WebSocket
    ///     })
    ///
    ///     HTTPServer.start(..., upgraders: [ws])
    ///
    /// - parameters:
    ///     - maxFrameSize: Maximum WebSocket frame size this server will accept.
    ///     - shouldUpgrade: Called when an incoming HTTPRequest attempts to upgrade.
    ///                      Return non-nil headers to accept the upgrade.
    ///     - onUpgrade: Called when a new WebSocket client has connected.
    /// - returns: An `HTTPProtocolUpgrader` for use with `HTTPServer`.
    public static func webSocketUpgrader(
        maxFrameSize: Int = 1 << 14,
        shouldUpgrade: @escaping (HTTPRequest) -> (HTTPHeaders?),
        onUpgrade: @escaping (WebSocket, HTTPRequest) -> ()
    ) -> HTTPProtocolUpgrader {
        return WebSocketUpgrader(maxFrameSize: maxFrameSize, shouldUpgrade: { head in
            let req = HTTPRequest(
                method: head.method,
                url: head.uri,
                version: head.version,
                headers: head.headers
            )
            return shouldUpgrade(req)
        }, upgradePipelineHandler: { channel, head in
            let req = HTTPRequest(
                method: head.method,
                url: head.uri,
                version: head.version,
                headers: head.headers
            )
            #warning("TODO: pass channel if necessary")
            // req.channel = channel
            let webSocket = WebSocket(channel: channel, mode: .server)
            return channel.pipeline.add(webSocket: webSocket).map {
                onUpgrade(webSocket, req)
            }
        })
    }
}

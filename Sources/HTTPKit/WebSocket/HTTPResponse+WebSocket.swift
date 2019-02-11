extension HTTPResponse {
    public mutating func webSocketUpgrade(
        headers: HTTPHeaders = [:],
        for req: HTTPRequest,
        onUpgrade: @escaping (WebSocket) -> ()
    ) throws {
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
            initialResponseHeaders: headers
        )
        for (name, value) in headers {
            self.headers.replaceOrAdd(name: name, value: value)
        }
        self.status = .switchingProtocols
        self.upgrader = upgrader
    }
}

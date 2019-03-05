extension HTTPRequest {
    public func makeWebSocketUpgradeResponse(
        extraHeaders: HTTPHeaders = [:],
        on channel: Channel,
        onUpgrade: @escaping (WebSocket) -> ()
    ) -> EventLoopFuture<HTTPResponse> {
        let upgrader = WebSocketUpgrader(shouldUpgrade: { channel, _ in
            return channel.eventLoop.makeSucceededFuture(extraHeaders)
        }, upgradePipelineHandler: { channel, req in
            let webSocket = WebSocket(channel: channel, mode: .server)
            onUpgrade(webSocket)
            return channel.pipeline.add(webSocket: webSocket)
        })
        
        var head = HTTPRequestHead(
            version: self.version,
            method: self.method,
            uri: self.urlString
        )
        head.headers = self.headers
        return upgrader.buildUpgradeResponse(
            channel: channel,
            upgradeRequest: head,
            initialResponseHeaders: headers
        ).map { headers in
            var res = HTTPResponse(
                status: .switchingProtocols,
                headers: headers
            )
            res.upgrader = upgrader
            return res
        }
    }
}

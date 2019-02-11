extension HTTPRequest {
    public func isRequestingUpgrade(to protocol: String) -> Bool {
        let connectionHeaders = Set(self.headers[canonicalForm: "connection"].map { $0.lowercased() })
        let upgradeHeaders = Set(self.headers[canonicalForm: "upgrade"].map { $0.lowercased() })
        
        return connectionHeaders.contains("upgrade") && upgradeHeaders.contains(`protocol`)
    }
    
    public mutating func webSocketUpgrade(onUpgrade: @escaping (WebSocket) -> ()) {
        self.upgrader = WebSocketClientUpgrader { channel, res in
            let ws = WebSocket(channel: channel, mode: .client)
            return channel.pipeline.add(webSocket: ws).map {
                onUpgrade(ws)
            }
        }
    }
}

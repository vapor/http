import URI
import HTTP
import Core

extension WebSocket {
    public static func background(to uri: String, using client: ClientProtocol.Type = Client<TCPClientStream>.self, protocols: [String]? = nil, onConnect: (WebSocket) throws -> Void) throws {
        let uri = try URI(uri)
        try background(to: uri, using: client, protocols: protocols, onConnect: onConnect)
    }

    public static func background(to uri: URI, using client: ClientProtocol.Type = Client<TCPClientStream>.self, protocols: [String]? = nil, onConnect: (WebSocket) throws -> Void) throws {
        _ = try Core.background {
            // TODO: Need to notify failure -- Result<WebSocket>?
            _ = try? connect(to: uri, using: client, protocols: protocols, onConnect: onConnect)
        }
    }

    public static func connect(to uri: String, using client: ClientProtocol.Type = Client<TCPClientStream>.self, protocols: [String]? = nil, onConnect: (WebSocket) throws -> Void) throws {
        let uri = try URI(uri)
        try connect(to: uri, using: client, protocols: protocols, onConnect: onConnect)
    }

    public static func connect(to uri: URI, using client: ClientProtocol.Type = Client<TCPClientStream>.self, protocols: [String]? = nil, onConnect: (WebSocket) throws -> Void) throws {
        guard !uri.host.isEmpty else { throw WebSocket.FormatError.invalidURI }

        let requestKey = WebSocket.makeRequestKey()

        var headers = [HeaderKey: String]()
        headers.secWebSocketKey = requestKey
        headers.connection = "Upgrade"
        headers.upgrade = "websocket"
        headers.secWebSocketVersion = "13"

        /*
            If protocols are empty they should not be added,
            it was kicking back errors on nginx proxies in tests
        */
        if let protocols = protocols, !protocols.isEmpty {
            headers.secWebProtocol = protocols
        }

        let client = try client.make(scheme: uri.scheme, host: uri.host, port: uri.port)
        // manually requesting to preserve queries that might be in URI easily
        let request = Request(
            method: .get,
            uri: uri,
            headers: headers
        )
        let response = try client.respond(to: request)

        // Don't need to check version in server response
        guard response.headers.connection == "Upgrade" else { throw FormatError.missingConnectionHeader }
        guard response.headers.upgrade == "websocket" else { throw FormatError.missingUpgradeHeader }
        guard case .switchingProtocols = response.status else { throw FormatError.invalidOrUnsupportedStatus }
        guard let accept = response.headers.secWebSocketAccept else { throw FormatError.missingSecAcceptHeader }
        let expected = WebSocket.exchange(requestKey: requestKey)
        guard accept == expected else { throw FormatError.invalidSecAcceptHeader }

        let ws = WebSocket(client.stream, mode: .client)
        try onConnect(ws)
        try ws.listen()
    }
}


extension WebSocket {
    /*
        The request MUST include a header field with the name
        |Sec-WebSocket-Key|.  The value of this header field MUST be a
        nonce consisting of a randomly selected 16-byte value that has
        been base64-encoded (see Section 4 of [RFC4648]).  The nonce
        MUST be selected randomly for each connection.
    */
    static func makeRequestKey() -> String {
        return makeRequestKeyBytes().base64String
    }

    private static func makeRequestKeyBytes() -> Bytes {
        return (1...16).map { _ in UInt8.random() }
    }
}

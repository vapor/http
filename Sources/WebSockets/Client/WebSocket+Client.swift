import Bits
import Core
import Transport
import Sockets

import URI
import HTTP

extension WebSocket {
    public static func background<C: ClientStream>(
        to uri: String,
        using client: C,
        protocols: [String]? = nil,
        headers: [HeaderKey: String]? = nil,
        onConnect: @escaping (WebSocket) throws -> Void
    )  throws {
        let uri = try URI(uri)
        try background(to: uri, using: client, protocols: protocols, headers: headers, onConnect: onConnect)
    }

    public static func background<C: ClientStream>(
        to uri: URI,
        using client: C,
        protocols: [String]? = nil,
        headers: [HeaderKey: String]? = nil,
        onConnect: @escaping (WebSocket) throws -> Void
    ) throws {
        Core.background {
            // TODO: Need to notify failure -- Result<WebSocket>?
            _ = try? connect(to: uri, using: client, protocols: protocols, headers: headers, onConnect: onConnect)
        }
    }

    public static func connect<C: ClientStream>(
        to uri: String,
        using client: C,
        protocols: [String]? = nil,
        headers: [HeaderKey: String]? = nil,
        onConnect: @escaping (WebSocket) throws -> Void
    ) throws {
        let uri = try URI(uri)
        try connect(to: uri, using: client, protocols: protocols, headers: headers,  onConnect: onConnect)
    }

    public static func connect<C: ClientStream>(
        to uri: URI,
        using stream: C,
        protocols: [String]? = nil,
        headers: [HeaderKey: String]? = nil,
        onConnect: @escaping (WebSocket) throws -> Void
    ) throws {
        guard !uri.hostname.isEmpty else { throw WebSocket.FormatError.invalidURI }

        let requestKey = WebSocket.makeRequestKey()

        var headers = headers ?? [HeaderKey:String]()
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
        
        let client = try BasicClient(stream)
        
        // manually requesting to preserve queries that might be in URI easily
        let request = Request(
            method: .get,
            uri: uri,
            headers: headers
        )
        let response = try client.respond(to: request)

        guard response.status == .switchingProtocols else { throw FormatError.invalidOrUnsupportedStatus(response.status) }
        // Don't need to check version in server response
        guard response.headers.connection?.lowercased() == "upgrade" else { throw FormatError.missingConnectionHeader }
        guard response.headers.upgrade?.lowercased() == "websocket" else { throw FormatError.missingUpgradeHeader }
        guard let accept = response.headers.secWebSocketAccept else { throw FormatError.missingSecAcceptHeader }
        let expected = try WebSocket.exchange(requestKey: requestKey)
        guard accept == expected else { throw FormatError.invalidSecAcceptHeader }

        let ws = WebSocket(stream, mode: .client)
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
        return makeRequestKeyBytes().base64Encoded.makeString()
    }

    private static func makeRequestKeyBytes() -> Bytes {
        return (1...16).map { _ in UInt8.random() }
    }
}

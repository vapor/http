import Core
import Transport
import Sockets

import URI
import HTTP

extension WebSocket {
    @available(*, deprecated, message: "Use background(to:, using:, maxPayloadSize:, protocols:, headers: onConnect:) instead.")
    public static func background<C: ClientStream>(
        to uri: String,
        using client: C,
        protocols: [String]? = nil,
        headers: [HeaderKey: String]? = nil,
        onConnect: @escaping (WebSocket) throws -> Void
        )  throws {
        try self.background(to: uri, using: client, maxPayloadSize: UInt64.max, protocols: protocols, headers: headers, onConnect: onConnect)
    }
    
    @available(*, deprecated, message: "Use background(to:, using:, maxPayloadSize:, protocols:, headers: onConnect:) instead.")
    public static func background<C: ClientStream>(
        to uri: URI,
        using client: C,
        protocols: [String]? = nil,
        headers: [HeaderKey: String]? = nil,
        onConnect: @escaping (WebSocket) throws -> Void
        ) throws {
        try self.background(to: uri, using: client, maxPayloadSize: UInt64.max, protocols: protocols, headers: headers, onConnect: onConnect)
    }
    
    @available(*, deprecated, message: "Use connect(to:, using:, maxPayloadSize:, protocols:, headers: onConnect:) instead.")
    public static func connect<C: ClientStream>(
        to uri: String,
        using client: C,
        protocols: [String]? = nil,
        headers: [HeaderKey: String]? = nil,
        onConnect: @escaping (WebSocket) throws -> Void
        ) throws {
        try self.connect(to: uri, using: client, maxPayloadSize: UInt64.max, protocols: protocols, headers: headers, onConnect: onConnect)
    }
    
    @available(*, deprecated, message: "Use connect(to:, using:, maxPayloadSize:, protocols:, headers: onConnect:) instead.")
    public static func connect<C: ClientStream>(
        to uri: URI,
        using stream: C,
        protocols: [String]? = nil,
        headers: [HeaderKey: String]? = nil,
        onConnect: @escaping (WebSocket) throws -> Void
        ) throws {
        try self.connect(to: uri, using: stream, maxPayloadSize: UInt64.max, protocols: protocols, headers: headers, onConnect: onConnect)
    }
}

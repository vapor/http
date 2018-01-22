import Async
import Crypto
import Dispatch
import Foundation
import TCP
import HTTP
import TLS

#if os(Linux)
    import OpenSSL
#else
    import AppleTLS
#endif
    
extension WebSocket {
    /// Create a new WebSocket client in a future.
    ///
    /// The future will be completed with the WebSocket connection once the handshake using HTTP is complete.
    ///
    /// - parameter uri: The URI containing the remote host to connect to.
    /// - parameter worker: The Worker which this websocket will use for managing read and write operations
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/websocket/client/#connecting-a-websocket-client)
    public static func connect(
        to uri: URI,
        on worker: Worker
    ) throws -> WebSocket {
        guard
            uri.scheme == "ws" || uri.scheme == "wss",
            let hostname = uri.hostname,
            let port = uri.port ?? uri.defaultPort
        else {
            throw WebSocketError(.invalidURI)
        }
        
        // Create a new socket to the host
        let socket = try TCPSocket(isNonBlocking: true)
        
        // The TCP Client that will be used by both HTTP and the WebSocket for communication
        let client = try TCPClient(socket: socket)
        
        if uri.scheme == "wss" {
            // FIXME: 
            #if os(Linux)
                let tlsClient = try OpenSSLClient(tcp: client, using: TLSClientSettings(peerDomainName: hostname))
            #else
                let tlsClient = try AppleTLSClient(tcp: client, using: TLSClientSettings(peerDomainName: hostname))
            #endif
            
            try tlsClient.connect(hostname: hostname, port: port)
            let socket = tlsClient.socket
            
            let source = socket.source(on: worker)
            let sink = socket.sink(on: worker)
            let websocket = WebSocket(source: .init(source), sink: .init(sink), worker: worker, server: false)
            try client.connect(hostname: hostname, port: port)
            websocket.upgrade(uri: uri)
            return websocket
        } else {
            let source = socket.source(on: worker)
            let sink = socket.sink(on: worker)
            let websocket = WebSocket(source: .init(source), sink: .init(sink), worker: worker, server: false)
            try client.connect(hostname: hostname, port: port)
            websocket.upgrade(uri: uri)
            return websocket
        }
    }
    
    static func upgrade(response: HTTPResponse, id: String) throws {
        // Calculates the expected key
        let expectatedKey = Base64Encoder().encode(data: SHA1.hash(id + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))
        
        let expectedKeyString = String(bytes: expectatedKey, encoding: .utf8) ?? ""
        
        // The server must accept the upgrade
        guard
            response.status == .upgrade,
            response.headers["Connection"] == "Upgrade",
            response.headers["Upgrade"] == "websocket"
        else {
            throw WebSocketError(.notUpgraded)
        }
        
        // Protocol version 13 uses `-Key` instead of `Accept`
        if response.headers["Sec-WebSocket-Version"] == "13",
            response.headers["Sec-WebSocket-Key"] == expectedKeyString {
        } else {
            // Fail if the handshake didn't return the expected accept-key
            guard response.headers["Sec-WebSocket-Accept"] == expectedKeyString else {
                throw WebSocketError(.notUpgraded)
            }
        }
    }
}

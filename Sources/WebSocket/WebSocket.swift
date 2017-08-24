import Foundation
import Core
import HTTP
import Crypto
import TCP

public class WebSocket {
    public let textStream = TextStream()
    public let binaryStream = BinaryStream()
    let connection: Connection

    /// Create a new WebSocket from a client
    public init(client: TCP.Client, serverSide: Bool = true) {
        self.connection = Connection(client: client, serverSide: serverSide)
        
        self.textStream.frameStream = self.connection
        self.binaryStream.frameStream = self.connection
        
        self.connection.drain(self.processFrame)
    }
    
    public func close() {
        do {
            let frame = try Frame(op: .close, payload: ByteBuffer(start: nil, count: 0), mask: connection.serverSide ? nil : randomMask(), isMasked: false)
            
            self.connection.inputStream(frame)
        } catch {}
    }
    
    /// Create a new WebSocket from a client
    public static func connect(to hostname: String, atPort port: UInt16, uri: URI, queue: DispatchQueue) throws -> Future<WebSocket> {
        let socket = try TCP.Socket()
        try socket.connect(hostname: hostname, port: port)
        
        let client = TCP.Client(socket: socket, queue: queue)
        
        let promise = Promise<WebSocket>()
        
        let httpClient = HTTP.Client(client: client)
        let serializer = RequestSerializer()
        let parser = ResponseParser()
        
        let uuid = NSUUID().uuidString
        
        let expectatedKey = try Base64Encoder.encode(data: SHA1.hash(uuid + "258EAFA5-E914-47DA-95CA-C5AB0DC85B1"))
        let expectatedKeyString = String(bytes: expectatedKey, encoding: .utf8) ?? ""
        
        let request = Request(method: .get, uri: uri, headers: [
            "Sec-WebSocket-Key": uuid,
            "Sec-WebSocket-Version": "13"
        ])
        
        serializer.errorStream = promise.fail
        
        serializer.stream(to: httpClient).stream(to: parser).drain { response in
            guard
                response.status == .upgrade,
                response.headers["Connection"] == "Upgrade",
                response.headers["Upgrade"] == "websocket",
                response.headers["Sec-WebSocket-Version"] == "13",
                response.headers["Sec-WebSocket-Key"] == expectatedKeyString else {
                    promise.fail(Error(.notUpgraded))
                    return
            }
            
            promise.complete(WebSocket(client: client, serverSide: false))
        }
        
        serializer.inputStream(request)
        
        return promise.future
    }
}

// MARK: Convenience

extension WebSocket {
    /// Returns true if this request should upgrade to websocket protocol
    public static func shouldUpgrade(for req: Request) -> Bool {
        return req.headers[.connection] == "Upgrade" && req.headers[.upgrade] == "websocket"
    }

    /// Creates a websocket upgrade response for the upgrade request
    public static func upgradeResponse(for req: Request) throws -> Response {
        guard
            req.method == .get,
            let key = req.headers["Sec-WebSocket-Key"],
            let secWebsocketVersion = req.headers["Sec-WebSocket-Version"],
            let version = Int(secWebsocketVersion)
        else {
            throw Error(.invalidRequest)
        }

        let headers: Headers

        let data = try Base64Encoder.encode(data: SHA1.hash(key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))
        let hash = String(bytes: data, encoding: .utf8) ?? ""

        if version > 13 {
            headers = [
                "Upgrade": "websocket",
                "Connection": "Upgrade",
                "Sec-WebSocket-Version": "13",
                "Sec-WebSocket-Key": hash
            ]
        } else {
            headers = [
                "Upgrade": "websocket",
                "Connection": "Upgrade",
                "Sec-WebSocket-Accept": hash
            ]
        }


        return Response(status: 101, headers: headers)
    }
}

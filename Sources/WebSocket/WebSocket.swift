import Foundation
import Core
import HTTP
import Crypto
import TCP

public class WebSocket {
    public let textStream = TextStream()
    public let binaryStream = BinaryStream()
    let connection: Connection
    var previousType: Frame.OpCode?
    
    public init(client: TCP.Client) {
        self.connection = Connection(client: client)
        
        self.textStream.frameStream = self.connection
        self.binaryStream.frameStream = self.connection
        
        self.connection.drain(self.processFrame)
    }
}

// MARK: Convenience

extension WebSocket {
    public static func shouldUpgrade(for req: Request) -> Bool {
        return req.headers[.connection] == "Upgrade" && req.headers[.upgrade] == "websocket"
    }

    public static func upgradeResponse(for req: Request) throws -> Response {
        guard
            req.method == .get,
            let key = req.headers["Sec-WebSocket-Key"],
            let secWebsocketVersion = req.headers["Sec-WebSocket-Version"],
            let version = Int(secWebsocketVersion)
        else {
            throw "bad websocket req"
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

extension String: Swift.Error {}

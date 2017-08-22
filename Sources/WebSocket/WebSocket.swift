import Foundation
import Core
import HTTP
import Crypto
import TCP

public class WebSocket {
    public let textStream = TextStream()
    public let binaryStream = BinaryStream()
    let connection: Connection
    let serializer: HTTP.ResponseSerializer
    var previousType: Frame.OpCode?
    
    init(client: Client, key: String, version: Int) throws {
        let headers: Headers
        
        let hash = String(bytes: try Base64Encoder.encode(bytes: SHA1.hash(key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11")), encoding: .utf8) ?? ""
        
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
        
        let response = Response(status: 101, headers: headers)
        
        self.serializer = HTTP.ResponseSerializer()
        serializer.drain(into: client)
        serializer.inputStream(response)
        
        self.connection = Connection(client: client)
        
        self.textStream.frameStream = self.connection
        self.binaryStream.frameStream = self.connection
        
        self.connection.drain(self.processFrame)
    }
}

public class WebSocketMiddleware : RequestMiddleware {
    public typealias Input = Request
    public typealias Output = Request
    
    public var outputStream: ((Request) -> ())?
    public var errorStream: BaseStream.ErrorHandler?
    var websocketStream: ((WebSocket) -> ())?
    
    public func onConnect(_ handler: @escaping ((WebSocket) -> ())) {
        self.websocketStream = handler
    }
    
    // prevent reference cycles
    weak var client: Client?
    
    public init(client: Client) {
        self.client = client
    }
    
    public func inputStream(_ request: Request) {
        guard
            request.method == .get,
            let key = request.headers["Sec-WebSocket-Key"],
            let secWebsocketVersion = request.headers["Sec-WebSocket-Version"],
            let version = Int(secWebsocketVersion),
            request.headers["Upgrade"] == "websocket",
            request.headers["Connection"] == "Upgrade" else {
                self.outputStream?(request)
                return
        }

        guard let client = client else {
            self.outputStream?(request)
            return
        }
        
        do {
            let websocket = try WebSocket(client: client, key: key, version: version)
            self.websocketStream?(websocket)
        } catch {
            self.errorStream?(error)
        }
    }
}

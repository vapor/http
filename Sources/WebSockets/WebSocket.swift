import Foundation
import Core
import HTTP
import Crypto
import TCP

public class WebSocket {
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
    }
}

public protocol RequestMiddleware : Core.Stream {
    associatedtype Input = Request
    associatedtype Output = Request
}

public protocol ResponseMiddleware : Core.Stream {
    associatedtype Input = Response
    associatedtype Output = Response
}

public class WebSocketMiddleware : RequestMiddleware {
    public typealias Input = Request
    public typealias Output = Request
    
    public var outputStream: ((Request) -> ())?
    public var errorStream: BaseStream.ErrorHandler?
    public var websocketStream: ((WebSocket) -> ())?
    
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
        }
        
        do {
            self.websocketStream?(try WebSocket(client: client, key: key, version: version))
        } catch {
            self.errorStream?(error)
        }
    }
}

internal final class WebSocketConnection : Core.Stream {
    func inputStream(_ input: Frame) {
        input.data
    }
    
    var outputStream: ((Frame) -> ())?
    
    var errorStream: BaseStream.ErrorHandler?
    
    internal typealias Input = Frame
    internal typealias Output = Frame
    
    let socket: Socket
}

public final class TextStream : Core.Stream {
    public typealias Input = String
    public typealias Output = String
    
    let connection: WebSocketConnection
    
    init(connection: WebSocketConnection) {
        self.connection = connection
    }
}

public final class BinaryStream : Core.Stream {
    public typealias Input = Data
    public typealias Output = Data
    
    let connection: WebSocketConnection
    
    init(connection: WebSocketConnection) {
        self.connection = connection
    }
}

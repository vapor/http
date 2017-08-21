import Foundation
import Core
import HTTP
import Crypto
import TCP

public class WebSocket {
    public let textStream = TextStream()
    public let binaryStream = BinaryStream()
    
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
        
        let serializer = HTTP.ResponseSerializer()
        serializer.drain(into: client)
        serializer.inputStream(response)
        
        let connection = WebSocketConnection(client: client)
        connection.drain { frame in
            switch frame.opCode {
            case .text:
                guard let string = frame.data.string() else {
                    return
                }
                
                self.textStream.inputStream(string)
            case .binary:
                
            }
        }
    }
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
            return
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
        client.drain { buffer in
            guard let pointer = buffer.baseAddress else {
                return
            }
            
            do {
                let frame = try Frame(from: pointer, length: buffer.count)
                self.outputStream?(frame)
            } catch {
                self.client.errorStream?(error)
            }
        }
    }
    
    var outputStream: ((Frame) -> ())?
    
    let message = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(UInt16.max))
    
    var errorStream: BaseStream.ErrorHandler?
    
    internal typealias Input = Frame
    internal typealias Output = Frame
    
    init(client: Client) {
        self.client = client
    }
    
    let client: Client
}

public final class TextStream : Core.Stream {
    public func inputStream(_ input: String) {
        do {
            _ = try input.withCString(encodedAs: UTF8.self) { pointer in
                try frameStream?.sendFrame(opcode: .text, pointer: pointer, length: input.utf8.count)
            }
        } catch {
            self.errorStream?(error)
        }
    }
    
    public var outputStream: ((String) -> ())?
    
    internal weak var frameStream: WebSocketConnection?
    
    public var errorStream: BaseStream.ErrorHandler?
    
    public typealias Input = String
    public typealias Output = String
    
    init() {}
}

public final class BinaryStream : Core.Stream {
    public func inputStream(_ input: ByteBuffer) {
        guard let pointer = input.baseAddress else {
            return
        }
        
        do {
            try frameStream?.sendFrame(opcode: .binary, pointer: pointer, length: input.count)
        } catch {
            self.errorStream?(error)
        }
    }
    
    public var outputStream: ((ByteBuffer) -> ())?
    
    internal weak var frameStream: WebSocketConnection?
    
    public var errorStream: BaseStream.ErrorHandler?
    
    public typealias Input = ByteBuffer
    public typealias Output = ByteBuffer
    
    init() {}
}

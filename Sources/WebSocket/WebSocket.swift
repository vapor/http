import Foundation
import Core
import HTTP
import Crypto
import TCP

public class WebSocket {
    public let textStream = TextStream()
    public let binaryStream = BinaryStream()
    let connection: Connection
    
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
        
        self.connection = Connection(client: client)
        var previousType: Frame.OpCode?
        
        self.textStream.frameStream = self.connection
        self.binaryStream.frameStream = self.connection
        
        self.connection.drain { frame in
            func processString() {
                // invalid string
                guard let string = frame.data.string() else {
                    self.connection.client.close()
                    return
                }
                
                self.textStream.outputStream?(string)
            }
            
            func processBinary() {
                let readBuffer = ByteBuffer(start: frame.data.baseAddress, count: frame.data.count)
                
                self.binaryStream.outputStream?(readBuffer)
            }
            
            switch frame.opCode {
            case .text:
                if !frame.final {
                    previousType = .text
                }
                
                processString()
            case .binary:
                if !frame.final {
                    previousType = .binary
                }
                
                processBinary()
            case .ping:
                guard let pointer = frame.data.baseAddress else {
                    self.connection.client.close()
                    return
                }
                
                do {
                    // reply the input
                    try self.connection.sendFrame(opcode: .pong, pointer: pointer, length: frame.data.count)
                } catch {
                    self.connection.errorStream?(error)
                }
            case .continuation:
                defer {
                    if frame.final {
                        previousType = nil
                    }
                }
                
                // TODO: ignore typeless continuations?
                guard let type = previousType else {
                    self.connection.client.close()
                    return
                }
                
                if type == .text {
                    processString()
                } else if type == .binary {
                    processBinary()
                } else {
                    // invalid, close or ignore?
                    self.connection.client.close()
                    return
                }
            case .close:
                self.connection.client.close()
            case .pong:
                return
            }
        }
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

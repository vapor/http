import Async
import Foundation
import Bits
import HTTP
import Crypto
import TCP

/// A websocket connection. Can be either the client or server side of the connection
///
/// [Learn More →](https://docs.vapor.codes/3.0/websocket/websocket/)
public class WebSocket {
    /// A stream of strings received from the remote
    let stringOutputStream: EmitterStream<String>
    
    /// A stream of binary data received from the remote
    let binaryOutputStream: EmitterStream<ByteBuffer>
    
    var backlog: [Frame]
    
    /// Serializes data into frames
    let serializer: FrameSerializer
    
    /// Parses frames from data
    let parser: FrameParser
    
    let server: Bool
    
    var errorCallback: (Error) -> () = { _ in }
    
    /// The underlying communication layer
    let source: AnyOutputStream<ByteBuffer>
    let sink: AnyInputStream<ByteBuffer>
    
    /// Create a new WebSocket from a TCP client for either the Client or Server Side
    ///
    /// Server side connections do not mask sent data
    ///
    /// - parameter client: The TCP.Client that the WebSocket connection runs on
    /// - parameter serverSide: If `true`, run the WebSocket as a server side connection.
    init(
        source: AnyOutputStream<ByteBuffer>,
        sink: AnyInputStream<ByteBuffer>,
        worker: Worker,
        server: Bool = true
    ) {
        self.backlog = []
        self.parser = source.stream(to: FrameParser(worker: worker))
        self.serializer = FrameSerializer(masking: !server)
        self.source = source
        self.sink = sink
        self.server = server
        
        self.stringOutputStream = EmitterStream<String>()
        self.binaryOutputStream = EmitterStream<ByteBuffer>()
        
        if server {
            bindFrameStreams()
        }
    }
    
    func upgrade(uri: URI) {
        // Generates the UUID that will make up the WebSocket-Key
        let id = OSRandom().data(count: 16).base64EncodedString()
        
        // Creates an HTTP client for the handshake
        let serializer = HTTPRequestSerializer().stream()
        
        let parser = HTTPResponseParser(maxSize: 50_000).stream()
        
        serializer.output(to: sink)
        
        let drain = DrainStream<HTTPResponse>(onInput: { response in
            try WebSocket.upgrade(response: response, id: id)
            
            self.bindFrameStreams()
        })
        
        source.stream(to: parser).output(to: drain)
        
        parser.request()
        
        let request = HTTPRequest(method: .get, uri: uri, headers: [
            .connection: "Upgrade",
            .upgrade: "websocket",
            .secWebSocketKey: id,
            .secWebSocketVersion: "13"
        ], body: HTTPBody())
        
        serializer.next(request)
    }
    
    func bindFrameStreams() {
        source.stream(to: parser).drain { upstream in
            upstream.request()
        }.output { frame in
            defer {
                self.parser.request()
            }
            
            frame.unmask()
            
            switch frame.opCode {
            case .close:
                self.sink.close()
                self.stringOutputStream.close()
                self.binaryOutputStream.close()
            case .text:
                let data = Data(buffer: frame.payload)
                
                guard let string = String(data: data, encoding: .utf8) else {
                    throw WebSocketError(.invalidFrame)
                }
                
                self.stringOutputStream.emit(string)
            case .continuation, .binary:
                let buffer = ByteBuffer(start: frame.buffer.baseAddress, count: frame.buffer.count)
                
                self.binaryOutputStream.emit(buffer)
            case .ping:
                let frame = Frame(op: .pong, payload: frame.payload, mask: self.nextMask)
                self.serializer.next(frame)
            case .pong: break
            }
        }.catch(onError: self.errorCallback).finally {
            self.sink.close()
        }
        
        self.serializer.output(to: self.sink)
    }
    
    var nextMask: [UInt8]? {
        return self.server ? nil : randomMask()
    }
    
    public func send(string: String) {
        Data(string.utf8).withByteBuffer { bytes in
            let frame = Frame(op: .text, payload: bytes, mask: nextMask)
            serializer.next(frame)
        }
    }
    
    public func send(data: Data) {
        data.withByteBuffer { bytes in
            let frame = Frame(op: .binary, payload: bytes, mask: nextMask)
            serializer.next(frame)
        }
    }
    
    public func send(bytes: ByteBuffer) {
        let frame = Frame(op: .binary, payload: bytes, mask: nextMask)
        serializer.next(frame)
    }
    
    
    @discardableResult
    public func onData(_ run: @escaping (WebSocket, Data) throws -> ()) -> DrainStream<ByteBuffer> {
        return binaryOutputStream.drain { upstream in
            upstream.request(count: .max)
        }.output { bytes in
            let data = Data(buffer: bytes)
            try run(self, data)
        }
    }
    
    
    @discardableResult
    public func onByteBuffer(_ run: @escaping (WebSocket, ByteBuffer) throws -> ()) -> DrainStream<ByteBuffer> {
        return binaryOutputStream.drain { upstream in
            upstream.request(count: .max)
        }.output { bytes in
            try run(self, bytes)
        }
    }
    
    @discardableResult
    public func onString(_ run: @escaping (WebSocket, String) throws -> ()) -> DrainStream<String> {
        return stringOutputStream.drain { upstream in
            upstream.request(count: .max)
        }.output { string in
            try run(self, string)
        }
    }
    
    /// Closes the connection to the other side by sending a `close` frame and closing the TCP connection
    public func close() {
        sink.close()
    }
}

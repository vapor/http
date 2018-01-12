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
    
    /// Allows push stream access to the frame serializer
    let serializerStream: PushStream<Frame>
    
    /// Serializes frames into data
    let serializer: FrameSerializer
    
    /// Parses frames from data
    let parser: TranslatingStreamWrapper<FrameParser>
    
    let server: Bool
    
    var errorCallback: (Error) -> () = { _ in }
    
    var worker: Worker
    
    var httpSerializerStream: PushStream<HTTPRequest>?
    
    /// Keeps track of sent pings that await a response
    var pings = [Data: Promise<Void>]()
    
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
        self.parser = FrameParser(worker: worker).stream(on: worker)
        self.serializer = FrameSerializer(masking: !server)
        self.source = source
        self.sink = sink
        self.worker = worker
        self.server = server
        
        self.stringOutputStream = EmitterStream<String>()
        self.binaryOutputStream = EmitterStream<ByteBuffer>()
        
        self.serializerStream = PushStream<Frame>()
    }
    
    /// Upgrades the connection over HTTP
    func upgrade(uri: URI) {
        // Generates the UUID that will make up the WebSocket-Key
        let id = OSRandom().data(count: 16).base64EncodedString()
        
        // Creates an HTTP client for the handshake
        let serializer = HTTPRequestSerializer().stream(on: self.worker)
        let serializerStream = PushStream<HTTPRequest>()
        
        let responseParser = HTTPResponseParser()
        responseParser.maxHeaderSize = 50_000
        
        let parser = responseParser.stream(on: self.worker)
        
        serializerStream.stream(to: serializer).output(to: self.sink)
        
        let drain = DrainStream<HTTPResponse>(onInput: { response, upstream in
            try WebSocket.upgrade(response: response, id: id)
            
            self.bindFrameStreams()
        })
        
        self.source.stream(to: parser).output(to: drain)
        
        parser.request()
        
        let request = HTTPRequest(method: .get, uri: uri, headers: [
            .connection: "Upgrade",
            .upgrade: "websocket",
            .secWebSocketKey: id,
            .secWebSocketVersion: "13"
        ], body: HTTPBody())
        
        self.httpSerializerStream = serializerStream
        serializerStream.next(request)
    }
    
    func bindFrameStreams() {
         _ = source.stream(to: parser).drain { frame, upstream in
            defer {
                self.parser.request()
            }
            
            frame.unmask()
            
            switch frame.opCode {
            case .close:
                self.parser.close()
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
                self.serializerStream.next(frame)
            case .pong:
                let data = Data(frame.payload)
                self.pings[data]?.complete()
            }
        }.catch(onError: self.errorCallback).finally {
            self.serializerStream.close()
        }
        
        parser.request()
        serializerStream.stream(to: self.serializer.stream(on: self.worker)).output(to: self.sink)
    }
    
    var nextMask: [UInt8]? {
        return self.server ? nil : randomMask()
    }
    
    public func send(string: String) {
        Data(string.utf8).withByteBuffer { bytes in
            let frame = Frame(op: .text, payload: bytes, mask: nextMask)
            self.serializerStream.next(frame)
        }
    }
    
    public func send(data: Data) {
        data.withByteBuffer { bytes in
            let frame = Frame(op: .binary, payload: bytes, mask: nextMask)
            self.serializerStream.next(frame)
        }
    }
    
    public func send(bytes: ByteBuffer) {
        let frame = Frame(op: .binary, payload: bytes, mask: nextMask)
        self.serializerStream.next(frame)
    }
    
    @discardableResult
    public func ping() -> Signal {
        let promise = Promise<Void>()
        let data = OSRandom().data(count: 32)
        
        self.pings[data] = promise
        
        data.withByteBuffer { bytes in
            let frame = Frame(op: .ping, payload: bytes, mask: nextMask)
            self.serializerStream.next(frame)
        }
        
        return promise.future
    }
    
    @discardableResult
    public func onData(_ run: @escaping (WebSocket, Data) throws -> ()) -> DrainStream<ByteBuffer> {
        return binaryOutputStream.drain { bytes, upstream in
            let data = Data(buffer: bytes)
            try run(self, data)
        }
    }
    
    
    @discardableResult
    public func onByteBuffer(_ run: @escaping (WebSocket, ByteBuffer) throws -> ()) -> DrainStream<ByteBuffer> {
        return binaryOutputStream.drain { bytes, upstream in
            try run(self, bytes)
        }
    }

    public func onString(_ run: @escaping (WebSocket, String) throws -> ()) -> DrainStream<String> {
        return stringOutputStream.drain { string, upstream in
            try run(self, string)
        }
    }
    
    /// Closes the connection to the other side by sending a `close` frame and closing the TCP connection
    public func close(_ data: Data = Data()) {
        data.withByteBuffer { bytes in
            let frame = Frame(op: .close, payload: bytes, mask: nextMask)
            self.serializerStream.next(frame)
            self.serializerStream.close()
        }
    }
}

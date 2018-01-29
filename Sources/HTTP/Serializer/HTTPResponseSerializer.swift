import COperatingSystem
import Async
import Bits
import Dispatch
import Foundation

/// Converts responses to Data.
public final class HTTPResponseSerializer: _HTTPSerializer {
    let buffer: MutableByteBuffer
    
    public var state: ByteSerializerState<HTTPResponseSerializer>
    
    /// See HTTPSerializer.Message
    public typealias Input = HTTPResponse
    public typealias SerializationState = HTTPSerializerState
    public typealias Output = ByteBuffer

    /// Serialized message
    var firstLine: [UInt8]?
    
    /// Headers
    var headersData: [UInt8]?

    /// Body data
    var body: HTTPBody?
    
    /// Create a new HTTPResponseSerializer
    public init(bufferSize: Int = 2048) {
        self.state = .init()
        
        let pointer = MutableBytesPointer.allocate(capacity: bufferSize)
        self.buffer = MutableByteBuffer(start: pointer, count: bufferSize)
    }
    
    /// Set up the variables for Message serialization
    public func setMessage(to message: HTTPResponse) {
        var headers = message.headers
        
        headers[.contentLength] = nil
        
        if case .chunkedOutputStream = message.body.storage {
            headers[.transferEncoding] = "chunked"
        } else {
            headers.appendValue(message.body.count.description, forName: .contentLength)
        }
        
        self.headersData = headers.storage
        
        self.firstLine = message.firstLine

        self.body = message.body
    }
    
    deinit {
        self.buffer.baseAddress?.deinitialize(count: self.buffer.count)
        self.buffer.baseAddress?.deallocate()
    }
}

fileprivate extension HTTPResponse {
    var firstLine: [UInt8] {
        // First line
        var http1Line = http1Prefix
        http1Line.reserveCapacity(128)
        
        http1Line.append(contentsOf: self.status.code.bytes(reserving: 3))
        http1Line.append(.space)
        http1Line.append(contentsOf: self.status.messageBytes)
        http1Line.append(contentsOf: crlf)
        return http1Line
    }
}

private let http1Prefix = [UInt8]("HTTP/1.1 ".utf8)
private let crlf = [UInt8]("\r\n".utf8)
private let headerKeyValueSeparator = [UInt8](": ".utf8)

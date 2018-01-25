import Async
import Bits
import Dispatch
import Foundation

/// Converts requests to DispatchData.
public final class HTTPRequestSerializer: _HTTPSerializer {
    public typealias SerializationState = HTTPSerializerState
    public typealias Input = HTTPRequest
    public typealias Output = ByteBuffer
    
    /// Serialized message
    var firstLine: [UInt8]?
    
    /// Headers
    var headersData: [UInt8]?

    /// Static body data
    var body: HTTPBody?
    
    public let state: ByteSerializerState<HTTPRequestSerializer>
    let buffer: MutableByteBuffer
    
    /// Create a new HTTPResponseSerializer
    public init(bufferSize: Int = 2048) {
        self.state = .init()
        
        let pointer = MutableBytesPointer.allocate(capacity: bufferSize)
        self.buffer = MutableByteBuffer(start: pointer, count: bufferSize)
    }
    
    /// Set up the variables for Message serialization
    public func setMessage(to message: HTTPRequest) {
        var headers = message.headers
        
        headers[.contentLength] = nil
        
        if case .chunkedOutputStream = message.body.storage {
            headers[.transferEncoding] = "chunked"
        } else {
            let count = message.body.count ?? 0
            headers.appendValue(count.bytes(reserving: 6), forName: .contentLength)
        }
        
        self.headersData = headers.storage
        
        self.firstLine = message.firstLine
        
        self.body = message.body
    }
    
    deinit {
        self.buffer.baseAddress?.deallocate(capacity: self.buffer.count)
    }
}

fileprivate extension HTTPRequest {
    var firstLine: [UInt8] {
        var firstLine = self.method.bytes
        firstLine.reserveCapacity(self.headers.storage.count + 256)
        
        firstLine.append(.space)
        
        if self.uri.pathBytes.first != .forwardSlash {
            firstLine.append(.forwardSlash)
        }
        
        firstLine.append(contentsOf: self.uri.pathBytes)
        
        if let query = self.uri.query {
            firstLine.append(.questionMark)
            firstLine.append(contentsOf: query.utf8)
        }
        
        if let fragment = self.uri.fragment {
            firstLine.append(.numberSign)
            firstLine.append(contentsOf: fragment.utf8)
        }
        
        firstLine.append(contentsOf: http1newLine)
        
        return firstLine
    }
}

fileprivate let crlf = Data([
    .carriageReturn,
    .newLine
])
fileprivate let http1newLine = [UInt8](" HTTP/1.1\r\n".utf8)

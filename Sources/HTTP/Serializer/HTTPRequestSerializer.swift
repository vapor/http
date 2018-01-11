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
    var headersData: Data?

    /// Static body data
    var staticBodyData: Data?
    
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
            self.headersData = headers.clean()
        } else {
            headers.appendValue(message.body.count.description, forName: .contentLength)
            self.headersData = headers.clean()
        }
        
        self.firstLine = message.firstLine
        
        switch message.body.storage {
        case .data(let data):
            self.staticBodyData = data
        case .dispatchData(let dispatchData):
            self.staticBodyData = Data(dispatchData)
        case .staticString(let staticString):
            let buffer = UnsafeBufferPointer(
                start: staticString.utf8Start,
                count: staticString.utf8CodeUnitCount
            )
            self.staticBodyData = Data(buffer)
        case .string(let string):
            self.staticBodyData = Data(string.utf8)
        case .chunkedOutputStream: break
        case .binaryOutputStream(_): break
        }
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

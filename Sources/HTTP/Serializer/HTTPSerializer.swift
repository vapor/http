import Async
import Bits
import Dispatch
import Foundation

/// A helper for Request and Response serializer that keeps state
public enum HTTPSerializerState {
    case noMessage
    case firstLine(offset: Int)
    case headers(offset: Int)
    case crlf(offset: Int)
    case staticBody(offset: Int)
    case streaming(AnyOutputStream<ByteBuffer>)
    
    mutating func next() {
        switch self {
        case .firstLine: self = .headers(offset: 0)
        case .headers: self = .crlf(offset: 0)
        case .crlf: self = .staticBody(offset: 0)
        default: self = .noMessage
        }
    }
    
    mutating func advance(_ n: Int) {
        switch self {
        case .firstLine(let offset): self = .firstLine(offset: offset + n)
        case .headers(let offset): self = .headers(offset: offset + n)
        case .crlf(let offset): self = .crlf(offset: offset + n)
        case .staticBody(let offset): self = .staticBody(offset: offset + n)
        default: self = .noMessage
        }
    }
    
    var ready: Bool {
        if case .noMessage = self {
            return true
        }
        
        return false
    }
}

/// Internal Swift HTTP serializer protocol.
public protocol HTTPSerializer: class, ByteSerializer where Input: HTTPMessage {
    func setMessage(to message: Input)
}

internal protocol _HTTPSerializer: HTTPSerializer where SerializationState == HTTPSerializerState {
    /// Serialized message
    var firstLine: [UInt8]? { get }
    
    /// Headers
    var headersData: Data? { get }

    /// Body data
    var body: HTTPBody? { get }
    
    var buffer: MutableByteBuffer { get }
}

extension _HTTPSerializer {
    public func serialize(_ input: Input, state previousState: SerializationState?) throws -> ByteSerializerResult<Self> {
        var bufferSize: Int
        var writeOffset = 0
        
        var state: SerializationState
            
        if let previousState = previousState {
            state = previousState
        } else {
            self.setMessage(to: input)
            state = .firstLine(offset: 0)
        }
        
        while !state.ready {
            let _offset: Int
            let writeSize: Int
            let outputSize = buffer.count - writeOffset
            
            switch state {
            case .noMessage:
                throw HTTPError(identifier: "no-message", reason: "Serialization requested without a message")
            case .firstLine(let offset):
                _offset = offset
                guard let firstLine = self.firstLine else {
                    throw HTTPError(identifier: "invalid-state", reason: "Missing first line metadata")
                }
                
                bufferSize = firstLine.count
                writeSize = min(outputSize, bufferSize - offset)
                
                firstLine.withUnsafeBytes { pointer in
                    _ = memcpy(buffer.baseAddress!.advanced(by: writeOffset), pointer.baseAddress!.advanced(by: offset), writeSize)
                }
            case .headers(let offset):
                _offset = offset
                guard let headersData = self.headersData else {
                    throw HTTPError(identifier: "invalid-state", reason: "Missing header state")
                }
                
                bufferSize = headersData.count
                writeSize = min(outputSize, bufferSize - offset)
                
                headersData.withByteBuffer { headerBuffer in
                    _ = memcpy(buffer.baseAddress!.advanced(by: writeOffset), headerBuffer.baseAddress!.advanced(by: offset), writeSize)
                }
            case .crlf(let offset):
                _offset = offset
                bufferSize = 2
                writeSize = min(outputSize, bufferSize - offset)
                
                crlf.withUnsafeBufferPointer { crlfBuffer in
                    _ = memcpy(buffer.baseAddress!.advanced(by: writeOffset), crlfBuffer.baseAddress!.advanced(by: offset), writeSize)
                }
            case .staticBody(let offset):
                _offset = offset
                
                guard let body = self.body else {
                    state.next()
                    continue
                }
                
                switch body.storage {
                case .chunkedOutputStream(let streamBuilder):
                    let stream = HTTPChunkEncodingStream()
                    let result = AnyOutputStream(streamBuilder(stream))
                    
                    return .incomplete(
                        ByteBuffer(start: buffer.baseAddress, count: writeOffset),
                        state: .streaming(result)
                    )
                case .binaryOutputStream(_, let stream):
                    return .incomplete(
                        ByteBuffer(start: buffer.baseAddress, count: writeOffset),
                        state: .streaming(stream)
                    )
                default:
                    bufferSize = body.count
                    writeSize = min(outputSize, bufferSize - offset)
                    
                    try body.withUnsafeBytes { pointer in
                        _ = memcpy(buffer.baseAddress!.advanced(by: writeOffset), pointer.advanced(by: offset), writeSize)
                    }
                }
            case .streaming(let stream):
                state.next()
                return .awaiting(stream, state: nil)
            }
            
            writeOffset += writeSize
            
            if _offset + writeSize < bufferSize {
                state.advance(writeSize)
                return .incomplete(ByteBuffer(start: buffer.baseAddress, count: writeOffset), state: state)
            } else {
                state.next()
            }
        }
        
        return .complete(ByteBuffer(start: buffer.baseAddress, count: writeOffset))
    }
}

fileprivate let crlf: [UInt8] = [.carriageReturn, .newLine]


import Foundation
import NIOFoundationCompat

/// The internal HTTP body storage enum. This is an implementation detail.
enum HTTPBodyStorage {
    /// Cases
    case none
    case buffer(ByteBuffer)
    case data(Data)
    case staticString(StaticString)
    case dispatchData(DispatchData)
    case string(String)
    case stream(HTTPBodyStream)

    /// The size of the HTTP body's data.
    /// `nil` is a stream.
    var count: Int? {
        switch self {
        case .data(let data): return data.count
        case .dispatchData(let data): return data.count
        case .staticString(let staticString): return staticString.utf8CodeUnitCount
        case .string(let string): return string.utf8.count
        case .buffer(let buffer): return buffer.readableBytes
        case .stream: return nil
        case .none: return 0
        }
    }

    /// Returns static data if not streaming.
    var data: Data? {
        switch self {
        case .buffer(var buffer): return buffer.readData(length: buffer.readableBytes)
        case .data(let data): return data
        case .dispatchData(let dispatchData): return Data(dispatchData)
        case .staticString(let staticString): return Data(bytes: staticString.utf8Start, count: staticString.utf8CodeUnitCount)
        case .string(let string): return Data(string.utf8)
        case .stream: return nil
        case .none: return nil
        }
    }
    
    var buffer: ByteBuffer? {
        switch self {
        case .buffer(let buffer): return buffer
        case .data(let data):
            var buffer = ByteBufferAllocator().buffer(capacity: data.count)
            buffer.writeBytes(data)
            return buffer
        case .dispatchData(let dispatchData):
            var buffer = ByteBufferAllocator().buffer(capacity: dispatchData.count)
            buffer.writeDispatchData(dispatchData)
            return buffer
        case .staticString(let staticString):
            var buffer = ByteBufferAllocator().buffer(capacity: staticString.utf8CodeUnitCount)
            buffer.writeStaticString(staticString)
            return buffer
        case .string(let string):
            var buffer = ByteBufferAllocator().buffer(capacity: string.count)
            buffer.writeString(string)
            return buffer
        case .stream: return nil
        case .none: return nil
        }
    }
}

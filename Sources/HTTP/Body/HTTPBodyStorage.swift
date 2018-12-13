import Foundation
import NIO
import NIOFoundationCompat

#warning("TODO: move to ByteBuffer as main storage method")

/// The internal HTTP body storage enum. This is an implementation detail.
enum HTTPBodyStorage {
    /// Cases
    case none
    case buffer(ByteBuffer)
    case data(Data)
    case staticString(StaticString)
    case dispatchData(DispatchData)
    case string(String)
    case chunkedStream(HTTPChunkedStream)

    /// The size of the HTTP body's data.
    /// `nil` of the body is a non-determinate stream.
    var count: Int? {
        switch self {
        case .data(let data): return data.count
        case .dispatchData(let data): return data.count
        case .staticString(let staticString): return staticString.utf8CodeUnitCount
        case .string(let string): return string.utf8.count
        case .buffer(let buffer): return buffer.readableBytes
        case .chunkedStream: return nil
        case .none: return 0
        }
    }

    /// Returns static data if not streaming.
    var data: Data? {
        switch self {
        case .buffer(var buffer): return buffer.readData(length: buffer.readableBytes)
        case .data(let data): return data
        case .dispatchData(let dispatch): return Data(dispatch)
        case .staticString(let string): return Data(bytes: string.utf8Start, count: string.utf8CodeUnitCount)
        case .string(let string): return Data(string.utf8)
        case .chunkedStream: return nil
        case .none: return nil
        }
    }

    /// Consumes data if streaming or returns static data.
    func consumeData(max: Int, on eventLoop: EventLoop) -> EventLoopFuture<Data> {
        if let data = self.data {
            return eventLoop.makeSucceededFuture(result: data)
        } else {
            switch self {
            case .chunkedStream(let stream): return stream.drain(max: max)
            case .none: return eventLoop.makeSucceededFuture(result: .init())
            default: fatalError("Unexpected HTTP body storage: \(self)")
            }
        }
    }
}

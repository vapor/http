import COperatingSystem
import Async
import Bits
import Dispatch
import Foundation

/// Converts responses to Data.
public final class HTTPResponseSerializer: HTTPSerializer {
    /// See `InputStream.Input`
    public typealias Input = HTTPResponse

    /// See `OutputStream.Output`
    public typealias Output = ByteBuffer

    /// See `HTTPSerializer.downstream`
    public var downstream: AnyInputStream<ByteBuffer>?

    /// See `HTTPSerializer.context`
    public var context: HTTPSerializerContext
    
    /// Create a new HTTPResponseSerializer
    public init() {
        context = .init()
    }

    /// See `HTTPSerializer.serializeStartLine(for:)`
    public func serializeStartLine(for message: HTTPResponse) -> ByteBuffer {
        switch message.status {
        case .ok: return okStartLine.withUTF8Buffer { $0 }
        default: fatalError()
        }
    }
}

private let okStartLine: StaticString = "HTTP/1.1 200 OK\r\n"

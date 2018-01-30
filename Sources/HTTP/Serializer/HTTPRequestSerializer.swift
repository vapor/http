import Async
import Bits
import Dispatch
import Foundation

/// https://stackoverflow.com/questions/417142/what-is-the-maximum-length-of-a-url-in-different-browsers
let maxStartLineSize = 2048

/// Serializing stream, converts HTTP Request to ByteBuffer.
public final class HTTPRequestSerializer: HTTPSerializer {
    /// See `InputStream.Input`
    public typealias Input = HTTPRequest

    /// See `OutputStream.Output`
    public typealias Output = ByteBuffer

    /// See `HTTPSerializer.downstream`
    public var downstream: AnyInputStream<ByteBuffer>?

    /// See `HTTPSerializer.context`
    public var context: HTTPSerializerContext

    /// Holds start lines for serialization
    private let startLineBuffer: MutableByteBuffer

    /// Creates a new `HTTPRequestSerializer`
    public init() {
        context = .init()
        let pointer = MutableBytesPointer.allocate(capacity: maxStartLineSize)
        startLineBuffer = .init(start: pointer, count: maxStartLineSize)
    }

    /// See `HTTPSerializer.serializeStartLine(for:)`
    public func serializeStartLine(for message: HTTPRequest) -> ByteBuffer {
        guard startLineBuffer.count >
            /// GET                          /foo                              HTTP/1.1\r\n
            message.method.bytes.count + 1 + message.uri.pathBytes.count + 1 + http1newLineBuffer.count
        else {
            fatalError("Start line too large for buffer")
        }

        var address = startLineBuffer.baseAddress!.advanced(by: 0)
        /// FIXME: static string?
        let methodBytes: ByteBuffer = message.method.bytes.withUnsafeBufferPointer { $0 }
        memcpy(address, methodBytes.baseAddress!, methodBytes.count)

        address = address.advanced(by: methodBytes.count)
        address.pointee = .space

        address = address.advanced(by: 1)
        let pathCount = message.uri.path.utf8.count
        let pathBytes = message.uri.path.withCString { $0 }
        memcpy(address, pathBytes, pathCount)

        address = address.advanced(by: pathCount)
        if let query = message.uri.query {
            address[0] = .questionMark
            address = address.advanced(by: 1)
            let bytes = Bytes(query.utf8)
            memcpy(address, bytes, bytes.count)
            address = address.advanced(by: bytes.count)
        }

        memcpy(address, http1newLineBuffer.baseAddress!, http1newLineBuffer.count)
        address = address.advanced(by: http1newLineBuffer.count)

        return ByteBuffer(
            start: startLineBuffer.baseAddress,
            count: startLineBuffer.baseAddress!.distance(to: address)
        )
    }

    deinit {
        startLineBuffer.baseAddress?.deinitialize()
        startLineBuffer.baseAddress?.deallocate(capacity: maxStartLineSize)
    }
}

fileprivate let http1newLine: StaticString = " HTTP/1.1\r\n"
fileprivate let http1newLineBuffer = http1newLine.withUTF8Buffer { $0 }

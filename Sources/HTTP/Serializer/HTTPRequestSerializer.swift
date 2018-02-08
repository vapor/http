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
        startLineBuffer = .allocate(capacity: maxStartLineSize)
    }

    /// See `HTTPSerializer.serializeStartLine(for:)`
    public func serializeStartLine(for message: HTTPRequest) -> ByteBuffer {
        let queryBytes = message.uri.query.flatMap { $0.utf8.count + 1 } ?? 0
        let newlineBuffer = message.version.minor == 0 ? http10newLineBuffer : http11newLineBuffer
        
        guard startLineBuffer.count >
            /// GET                          /foo                          ?a=b             HTTP/1.1\r\n
            message.method.bytes.count + 1 + message.uri.pathBytes.count + queryBytes + 1 + newlineBuffer.count
        else {
            fatalError("Start line too large for buffer")
        }

        var address = startLineBuffer.baseAddress!.advanced(by: 0)
        /// FIXME: static string?
        message.method.bytes.withUnsafeBufferPointer {
            address.initialize(from: $0.baseAddress!, count: $0.count)
            address = address.advanced(by: $0.count)
        }
        address.pointee = .space
        address = address.advanced(by: 1)

        let pathCount = message.uri.path.utf8.count
        message.uri.path.withCString {
            $0.withMemoryRebound(to: Byte.self, capacity: pathCount) {
                address.initialize(from: $0, count: pathCount)
                address = address.advanced(by: pathCount)
            }
        }

        if let query = message.uri.query {
            address.pointee = .questionMark
            address = address.advanced(by: 1)
            _ = UnsafeMutableBufferPointer(start: address, count: queryBytes - 1).initialize(from: query.utf8)
            address = address.advanced(by: queryBytes - 1)
        }

        address.initialize(from: newlineBuffer.baseAddress!, count: newlineBuffer.count)
        address = address.advanced(by: newlineBuffer.count)

        return ByteBuffer(
            start: startLineBuffer.baseAddress,
            count: startLineBuffer.baseAddress!.distance(to: address)
        )
    }

    deinit {
        startLineBuffer.deallocate()
    }
}

fileprivate let http10newLine: StaticString = " HTTP/1.0\r\n"
fileprivate let http10newLineBuffer = http10newLine.withUTF8Buffer { $0.allocateAndInitializeCopy() }

fileprivate let http11newLine: StaticString = " HTTP/1.1\r\n"
fileprivate let http11newLineBuffer = http11newLine.withUTF8Buffer { $0.allocateAndInitializeCopy() }

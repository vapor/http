import COperatingSystem
import Async
import Bits
import Dispatch
import Foundation

private let startLineBufferSize = 1024

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

    /// Start line buffer for non-precoded start lines.
    private var startLineBuffer: MutableByteBuffer?
    
    /// Create a new HTTPResponseSerializer
    public init() {
        context = .init()
    }

    /// See `HTTPSerializer.serializeStartLine(for:)`
    public func serializeStartLine(for message: HTTPResponse) -> ByteBuffer {
        switch message.status {
        case .ok: return okStartLine.withUTF8Buffer { $0 }
        case .notFound: return notFoundStartLine.withUTF8Buffer { $0 }
        case .internalServerError: return internalServerErrorStartLine.withUTF8Buffer { $0 }
        default:
            let buffer: MutableByteBuffer
            if let existing = self.startLineBuffer {
                buffer = existing
            } else {
                let new = MutableByteBuffer(start: .allocate(capacity: startLineBufferSize), count: startLineBufferSize)
                buffer = new
            }

            // `HTTP/1.1 `
            var pos = buffer.start.advanced(by: 0)
            memcpy(pos, version.withUTF8Buffer { $0 }.start, version.utf8CodeUnitCount)

            // `200`
            pos = pos.advanced(by: version.utf8CodeUnitCount)
            let codeBytes = message.status.code.bytes()
            memcpy(pos, codeBytes, codeBytes.count)

            // ` `
            pos = pos.advanced(by: codeBytes.count)
            pos[0] = .space

            // `OK`
            pos = pos.advanced(by: 1)
            let messageBytes = message.status.messageBytes
            memcpy(pos, messageBytes, messageBytes.count)

            // `\r\n`
            pos = pos.advanced(by: messageBytes.count)
            pos[0] = .carriageReturn
            pos[1] = .newLine
            pos = pos.advanced(by: 2)

            // view
            let view = ByteBuffer(start: buffer.start, count: buffer.start.distance(to: pos))
            return view
        }
    }

    deinit {
        if let buffer = startLineBuffer {
            buffer.baseAddress!.deinitialize()
            buffer.baseAddress?.deallocate(capacity: buffer.count)
        }
    }
}

private let version: StaticString = "HTTP/1.1 "

private let okStartLine: StaticString = "HTTP/1.1 200 OK\r\n"
private let notFoundStartLine: StaticString = "HTTP/1.1 404 Not Found\r\n"
private let internalServerErrorStartLine: StaticString = "HTTP/1.1 500 Internal Server Error\r\n"

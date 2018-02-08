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
    /// Can't make it lazy because deinit{} would cause it always to be allocated
    /// even when not needed.
    private var startLineBuffer: MutableByteBuffer?
    
    /// Create a new HTTPResponseSerializer
    public init() {
        context = .init()
    }

    /// See `HTTPSerializer.serializeStartLine(for:)`
    public func serializeStartLine(for message: HTTPResponse) -> ByteBuffer {
        switch message.status {
        case .ok: return okStartLineBuffer
        case .notFound: return notFoundStartLineBuffer
        case .internalServerError: return internalServerErrorStartLineBuffer
        default:
            if startLineBuffer == nil {
                startLineBuffer = MutableByteBuffer.allocate(capacity: startLineBufferSize)
            }
            
            // `HTTP/1.1 `
            var pos = startLineBuffer!.start
            pos.initialize(from: versionBuffer.baseAddress!, count: versionBuffer.count)
            pos = pos.advanced(by: versionBuffer.count)

            // `200`
            let codeBytes = message.status.code.bytes()
            _ = UnsafeMutableBufferPointer(start: pos, count: codeBytes.count).initialize(from: codeBytes)
            pos = pos.advanced(by: codeBytes.count)

            // ` `
            pos.pointee = .space
            pos = pos.advanced(by: 1)

            // `OK`
            let messageBytes = message.status.messageBytes
            _ = UnsafeMutableBufferPointer(start: pos, count: messageBytes.count).initialize(from: messageBytes)
            pos = pos.advanced(by: messageBytes.count)

            // `\r\n`
            pos[0] = .carriageReturn
            pos[1] = .newLine
            pos = pos.advanced(by: 2)

            // view
            let view = ByteBuffer(start: startLineBuffer!.start, count: startLineBuffer!.start.distance(to: pos))
            return view
        }
    }

    deinit {
        startLineBuffer?.deallocate()
    }
}

private let version: StaticString = "HTTP/1.1 "
private let versionBuffer: ByteBuffer = version.withUTF8Buffer { $0.allocateAndInitializeCopy() }

private let okStartLine: StaticString = "HTTP/1.1 200 OK\r\n"
private let okStartLineBuffer: ByteBuffer = okStartLine.withUTF8Buffer { $0.allocateAndInitializeCopy() }

private let notFoundStartLine: StaticString = "HTTP/1.1 404 Not Found\r\n"
private let notFoundStartLineBuffer: ByteBuffer = notFoundStartLine.withUTF8Buffer { $0.allocateAndInitializeCopy() }

private let internalServerErrorStartLine: StaticString = "HTTP/1.1 500 Internal Server Error\r\n"
private let internalServerErrorStartLineBuffer: ByteBuffer = internalServerErrorStartLine.withUTF8Buffer { $0.allocateAndInitializeCopy() }

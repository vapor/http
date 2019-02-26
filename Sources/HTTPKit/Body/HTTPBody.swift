import Foundation
import NIO

/// Represents an `HTTPMessage`'s body.
///
///     let body = HTTPBody(string: "Hello, world!")
///
/// This can contain any data (streaming or static) and should match the message's `"Content-Type"` header.
public struct HTTPBody: LosslessHTTPBodyRepresentable, CustomStringConvertible, CustomDebugStringConvertible {
    /// An empty `HTTPBody`.
    public static let empty: HTTPBody = .init()

    /// Returns the body's contents as `Data`. `nil` if the body is streaming.
    public var data: Data? {
        return storage.data
    }
    
    /// Returns the body's contents as `ByteBuffer`. `nil` if the body is streaming.
    public var buffer: ByteBuffer? {
        return self.storage.buffer
    }
    
    public var stream: HTTPBodyStream? {
        switch self.storage {
        case .stream(let stream): return stream
        default: return nil
        }
    }

    /// The size of the body's contents. `nil` if the body is streaming.
    public var count: Int? {
        return storage.count
    }

    /// See `CustomStringConvertible`.
    public var description: String {
        switch storage {
        case .data, .buffer, .dispatchData, .staticString, .string, .none: return debugDescription
        case .stream(let stream):
            guard !stream.isClosed else {
                return debugDescription
            }
            return "<chunked stream, use `debugPrint(_:)` to consume>"
        }
    }

    /// See `CustomDebugStringConvertible`.
    public var debugDescription: String {
        switch storage {
        case .none: return "<no body>"
        case .buffer(let buffer): return buffer.getString(at: 0, length: buffer.readableBytes) ?? "n/a"
        case .data(let data): return String(data: data, encoding: .ascii) ?? "n/a"
        case .dispatchData(let data): return String(data: Data(data), encoding: .ascii) ?? "n/a"
        case .staticString(let string): return string.description
        case .string(let string): return string
        case .stream(let stream):
            guard !stream.isClosed else {
                return "<consumed chunk stream>"
            }
            do {
                var data = try stream.consume(max: maxDebugStreamingBodySize).wait()
                return data.readString(length: data.readableBytes) ?? "<n/a>"
            } catch {
                return "<chunked stream error: \(error)>"
            }
        }
    }

    /// Internal storage.
    var storage: HTTPBodyStorage

    /// Creates an empty body. Useful for `GET` requests where HTTP bodies are forbidden.
    public init() {
        self.storage = .none
    }

    /// Create a new body wrapping `Data`.
    public init(data: Data) {
        storage = .data(data)
    }

    /// Create a new body wrapping `DispatchData`.
    public init(dispatchData: DispatchData) {
        storage = .dispatchData(dispatchData)
    }

    /// Create a new body from the UTF8 representation of a `StaticString`.
    public init(staticString: StaticString) {
        storage = .staticString(staticString)
    }

    /// Create a new body from the UTF8 representation of a `String`.
    public init(string: String) {
        self.storage = .string(string)
    }

    /// Create a new body from an `HTTPChunkedStream`.
    public init(stream: HTTPBodyStream) {
        self.storage = .stream(stream)
    }

    /// Create a new body from a Swift NIO `ByteBuffer`.
    public init(buffer: ByteBuffer) {
        self.storage = .buffer(buffer)
    }

    /// Internal init.
    internal init(storage: HTTPBodyStorage) {
        self.storage = storage
    }

    /// Consumes the body if it is a stream. Otherwise, returns the same value as the `data` property.
    ///
    ///     let data = try httpRes.body.consumeData(max: 1_000_000, on: ...).wait()
    ///
    /// - parameters:
    ///     - max: The maximum streaming body size to allow.
    ///            This only applies to streaming bodies, like chunked streams.
    ///            Defaults to 1MB.
    ///     - eventLoop: The event loop to perform this async work on.
    public func consume(max: Int = 1_000_000, on eventLoop: EventLoop) -> EventLoopFuture<ByteBuffer> {
        if let buffer = self.buffer {
            return eventLoop.makeSucceededFuture(buffer)
        } else if let stream = self.stream {
            return stream.consume(max: max)
        } else {
            let empty = ByteBufferAllocator().buffer(capacity: 0)
            return eventLoop.makeSucceededFuture(empty)
        }
    }

    /// See `LosslessHTTPBodyRepresentable`.
    public func convertToHTTPBody() -> HTTPBody {
        return self
    }
}

/// Maximum streaming body size to use for `debugPrint(_:)`.
private let maxDebugStreamingBodySize: Int = 1_000_000

import struct Foundation.Data
import struct Foundation.DispatchData
import NIOFoundationCompat

/// Represents an `HTTPMessage`'s body.
///
///     let body = HTTPBody(string: "Hello, world!")
///
/// This can contain any data (streaming or static) and should match the message's `"Content-Type"` header.
public struct HTTPBody: CustomStringConvertible, CustomDebugStringConvertible, ExpressibleByStringLiteral {
    public final class Stream {
        /// Supported types that can be sent and recieved from a `HTTPChunkedStream`.
        public enum Result {
            /// A normal data chunk.
            /// There will be 0 or more of these.
            case chunk(ByteBuffer)
            /// Indicates an error.
            /// There will be 0 or 1 of these. 0 if the stream closes cleanly.
            case error(Error)
            /// Indicates the stream has completed.
            /// There will be 0 or 1 of these. 0 if the stream errors.
            case end
        }
        
        /// Handles an incoming `HTTPChunkedStreamResult`.
        public typealias Handler = (Result, Stream) -> ()
        
        /// See `BasicWorker`.
        public var eventLoop: EventLoop
        
        /// If `true`, this `HTTPChunkedStream` has already sent an `end` chunk.
        public private(set) var isClosed: Bool
        
        /// This stream's `HTTPChunkedHandler`, if one is set.
        private var handler: Handler?
        
        /// If a `handler` has not been set when `write(_:)` is called, this property
        /// is used to store the waiting data.
        private var buffer: [Result]
        
        /// Creates a new `HTTPChunkedStream`.
        ///
        /// - parameters:
        ///     - worker: `Worker` to complete futures on.
        public init(on eventLoop: EventLoop) {
            self.eventLoop = eventLoop
            self.isClosed = false
            self.buffer = []
        }
        
        /// Sets a handler for reading `HTTPChunkedStreamResult`s from the stream.
        ///
        ///     chunkedStream.read { res, stream in
        ///         print(res) // prints the chunk
        ///         return .done(on: stream) // you can do async work or just return done
        ///     }
        ///
        /// - parameters:
        ///     - handler: `HTTPChunkedHandler` to use for receiving chunks from this stream.
        public func read(_ handler: @escaping Handler) {
            self.handler = handler
            for item in self.buffer {
                handler(item, self)
            }
            self.buffer = []
        }
        
        /// Writes a `HTTPChunkedStreamResult` to the stream.
        ///
        ///     try chunkedStream.write(.end).wait()
        ///
        /// You must wait for the returned `Future` to complete before writing additional data.
        ///
        /// - parameters:
        ///     - chunk: A `HTTPChunkedStreamResult` to write to the stream.
        /// - returns: A `Future` that will be completed when the write was successful.
        ///            You must wait for this future to complete before calling `write(_:)` again.
        public func write(_ chunk: Result) {
            if case .end = chunk {
                self.isClosed = true
            }
            
            if let handler = handler {
                handler(chunk, self)
            } else {
                self.buffer.append(chunk)
            }
        }
        
        /// Reads all `HTTPChunkedStreamResult`s from this stream until `end` is received.
        /// The output is combined into a single `Data`.
        ///
        ///     let data = try stream.drain(max: ...).wait()
        ///     print(data) // Data
        ///
        /// - parameters:
        ///     - max: The maximum number of bytes to allow before throwing an error.
        ///            Use this to prevent using excessive memory on your server.
        /// - returns: `Future` containing the collected `Data`.
        public func consume(max: Int) -> EventLoopFuture<ByteBuffer> {
            let promise = eventLoop.makePromise(of: ByteBuffer.self)
            var data = ByteBufferAllocator().buffer(capacity: 0)
            self.read { chunk, stream in
                switch chunk {
                case .chunk(var buffer):
                    if data.readableBytes + buffer.readableBytes >= max {
                        let error = HTTPError(.maxBodySize)
                        promise.fail(error)
                    } else {
                        data.writeBuffer(&buffer)
                    }
                case .error(let error): promise.fail(error)
                case .end: promise.succeed(data)
                }
            }
            return promise.futureResult
        }
        
        /// See `HTTPBodyRepresentable`.
        public func convertToHTTPBody() -> HTTPBody {
            return .init(stream: self)
        }
    }

    /// The internal HTTP body storage enum. This is an implementation detail.
    internal enum Storage {
        /// Cases
        case none
        case buffer(ByteBuffer)
        case data(Data)
        case dispatchData(DispatchData)
        case staticString(StaticString)
        case stream(Stream)
        case string(String)
    }
    
    /// An empty `HTTPBody`.
    public static let empty: HTTPBody = .init()
    
    public var string: String? {
        switch self.storage {
        case .buffer(var buffer): return buffer.readString(length: buffer.readableBytes)
        case .data(let data): return String(decoding: data, as: UTF8.self)
        case .dispatchData(let dispatchData): return String(decoding: dispatchData, as: UTF8.self)
        case .staticString(let staticString): return staticString.description
        case .string(let string): return string
        default: return nil
        }
    }
    
    public var stream: Stream? {
        switch self.storage {
        case .stream(let stream): return stream
        default: return nil
        }
    }
    
    /// The size of the HTTP body's data.
    /// `nil` is a stream.
    public var count: Int? {
        switch self.storage {
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
    public var data: Data? {
        switch self.storage {
        case .buffer(var buffer): return buffer.readData(length: buffer.readableBytes)
        case .data(let data): return data
        case .dispatchData(let dispatchData): return Data(dispatchData)
        case .staticString(let staticString): return Data(bytes: staticString.utf8Start, count: staticString.utf8CodeUnitCount)
        case .string(let string): return Data(string.utf8)
        case .stream: return nil
        case .none: return nil
        }
    }
    
    public var buffer: ByteBuffer? {
        switch self.storage {
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
    
    internal var storage: Storage
    
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

    /// Create a new body from an `HTTPBodyStream`.
    public init(stream: Stream) {
        self.storage = .stream(stream)
    }

    /// Create a new body from a Swift NIO `ByteBuffer`.
    public init(buffer: ByteBuffer) {
        self.storage = .buffer(buffer)
    }
    
    /// `ExpressibleByStringLiteral` conformance.
    public init(stringLiteral value: String) {
        self.storage = .string(value)
    }

    /// Internal init.
    internal init(storage: Storage) {
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

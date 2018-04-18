/// A `"Transfer-Encoding: chunked"` stream of data used by `HTTPBody`.
///
///     let chunkedStream = HTTPChunkedStream(on: req)
///     background {
///         while true {
///             sleep(1)
///             try! chunkedStream.write(...).wait()
///         }
///     }
///     return try HTTPResponse(status: .ok, body: chunkedStream)
///
/// `HTTPChunkedStream` allows you to send data asynchronously without a predefined length.
/// The `HTTPMessage` will be considered complete when the end chunk is sent.
public final class HTTPChunkedStream: BasicWorker, LosslessHTTPBodyRepresentable {
    /// Handles an incoming `HTTPChunkedStreamResult`.
    public typealias HTTPChunkedHandler = (HTTPChunkedStreamResult, HTTPChunkedStream) -> Future<Void>

    /// This stream's `HTTPChunkedHandler`, if one is set.
    private var handler: HTTPChunkedHandler?

    /// If a `handler` has not been set when `write(_:)` is called, this property
    /// is used to store the waiting data.
    private var waiting: (HTTPChunkedStreamResult, Promise<Void>)?

    /// See `BasicWorker`.
    public var eventLoop: EventLoop

    /// If `true`, this `HTTPChunkedStream` has already sent an `end` chunk.
    public private(set) var isClosed: Bool

    /// Creates a new `HTTPChunkedStream`.
    ///
    /// - parameters:
    ///     - worker: `Worker` to complete futures on.
    public init(on worker: Worker) {
        self.eventLoop = worker.eventLoop
        self.isClosed = false
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
    public func read(_ handler: @escaping HTTPChunkedHandler) {
        self.handler = handler
        if let (chunk, promise) = waiting {
            handler(chunk, self).cascade(promise: promise)
        }
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
    public func write(_ chunk: HTTPChunkedStreamResult) -> Future<Void> {
        if case .end = chunk {
            self.isClosed = true
        }

        if let handler = handler {
            return handler(chunk, self)
        } else {
            let promise = eventLoop.newPromise(Void.self)
            assert(waiting == nil)
            waiting = (chunk, promise)
            return promise.futureResult
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
    public func drain(max: Int) -> Future<Data> {
        let promise = eventLoop.newPromise(Data.self)
        var data = Data()
        handler = { chunk, stream in
            switch chunk {
            case .chunk(var buffer):
                if data.count + buffer.readableBytes >= max {
                    let error = HTTPError(identifier: "bodySize", reason: "HTTPBody was larger than max limit.")
                    promise.fail(error: error)
                } else {
                    data += buffer.readData(length: buffer.readableBytes) ?? Data()
                }
            case .error(let error): promise.fail(error: error)
            case .end: promise.succeed(result: data)
            }
            return .done(on: stream)
        }
        return promise.futureResult
    }

    /// See `HTTPBodyRepresentable`.
    public func convertToHTTPBody() -> HTTPBody {
        return .init(chunked: self)
    }
}

/// Supported types that can be sent and recieved from a `HTTPChunkedStream`.
public enum HTTPChunkedStreamResult {
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

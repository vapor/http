import Foundation

public enum HTTPChunkedStreamResult {
    case chunk(ByteBuffer)
    case error(Error)
    case end
}

public final class HTTPChunkedStream: BasicWorker {
    public typealias HTTPChunkedHandler = (HTTPChunkedStreamResult, HTTPChunkedStream) -> Future<Void>
    private var handler: HTTPChunkedHandler?
    private var waiting: (HTTPChunkedStreamResult, Promise<Void>)?
    public var eventLoop: EventLoop
    public private(set) var isClosed: Bool

    public init(on worker: Worker) {
        self.eventLoop = worker.eventLoop
        self.isClosed = false
    }

    public func read(_ handler: @escaping HTTPChunkedHandler) {
        self.handler = handler
        if let (chunk, promise) = waiting {
            handler(chunk, self).chain(to: promise)
        }
    }

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

    public func drain(max: Int) -> Future<Data> {
        let promise = eventLoop.newPromise(Data.self)
        var data = Data()
        handler = { chunk, stream in
            switch chunk {
            case .chunk(var buffer):
                if data.count + buffer.readableBytes >= max {
                    let error = HTTPError(identifier: "bodySize", reason: "HTTPBody was larger than max limit", source: .capture())
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
}

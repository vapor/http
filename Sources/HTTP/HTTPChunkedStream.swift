import Foundation

public enum HTTPChunkedStreamResult {
    case chunk(ByteBuffer)
    case error(Error)
    case end
}

public final class HTTPChunkedStream {
    public typealias HTTPChunkedHandler = (HTTPChunkedStreamResult) -> ()
    private var handler: HTTPChunkedHandler?
    private var eventLoop: EventLoop
    private var queue: [HTTPChunkedStreamResult]
    public private(set) var isClosed: Bool

    public init(on worker: Worker) {
        self.queue = []
        self.eventLoop = worker.eventLoop
        self.isClosed = false
    }

    public func read(_ handler: @escaping HTTPChunkedHandler) {
        while let chunk = queue.popLast() {
            handler(chunk)
        }
        self.handler = handler
    }

    public func write(_ chunk: HTTPChunkedStreamResult) {
        if case .end = chunk {
            self.isClosed = true
        }

        if let handler = handler {
            handler(chunk)
        } else {
            self.queue.insert(chunk, at: 0)
        }
    }

    public func drain(max: Int) -> Future<Data> {
        let promise = eventLoop.newPromise(Data.self)
        var data = Data()
        handler = { chunk in
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
        }
        return promise.futureResult
    }
}

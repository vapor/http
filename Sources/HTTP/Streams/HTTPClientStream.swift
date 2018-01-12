import Async
import Bits

/// An inverse client stream accepting responses and outputting requests.
/// Used to implement HTTPClient. Should be kept internal
internal final class HTTPClientStream<SourceStream, SinkStream>: Stream, ConnectionContext where
    SourceStream: OutputStream,
    SourceStream.Output == ByteBuffer,
    SinkStream: InputStream,
    SinkStream.Input == ByteBuffer
{
    /// See InputStream.Input
    typealias Input = HTTPResponse

    /// See OutputStream.Output
    typealias Output = HTTPRequest

    /// Queue of promised responses
    var responseQueue: [Promise<HTTPResponse>]

    /// Queue of requests to be serialized
    var requestQueue: [HTTPRequest]

    /// Accepts serialized requests
    var downstream: AnyInputStream<Output>?

    /// Serialized requests
    var remainingDownstreamRequests: UInt

    /// Parsed responses
    var upstream: ConnectionContext?

    /// The source bytestream
    let source: SourceStream

    /// The sink bytestream
    let sink: SinkStream
    
    let worker: Worker

    /// Creates a new HTTP client stream
    init(source: SourceStream, sink: SinkStream, worker: Worker, maxResponseSize: Int = 10_000_000) {
        self.responseQueue = []
        self.requestQueue = []
        self.remainingDownstreamRequests = 0
        self.source = source
        self.sink = sink
        self.worker = worker

        let serializerStream = HTTPRequestSerializer().stream(on: worker)
        let parser = HTTPResponseParser()
        let parserStream = parser.stream(on: worker)

        source
            .stream(to: parserStream)
            .stream(to: self)
            .stream(to: serializerStream)
            .output(to: sink)
    }

    /// Updates the stream's state. If there are outstanding
    /// downstream requests, they will be fulfilled.
    func update() {
        guard remainingDownstreamRequests > 0 else {
            return
        }
        while let request = requestQueue.popLast() {
            remainingDownstreamRequests -= 1
            downstream?.next(request)
        }
    }

    /// See ConnectionContext.connection
    func connection(_ event: ConnectionEvent) {
        switch event {
        case .request(let count):
            let isSuspended = remainingDownstreamRequests == 0
            remainingDownstreamRequests += count
            upstream?.request(count: count)
            if isSuspended { update() }
        case .cancel:
            /// FIXME: better cancel support
            remainingDownstreamRequests = 0
        }
    }

    /// See OutputStream.output
    func output<S>(to inputStream: S) where S : InputStream, S.Input == HTTPRequest {
        downstream = AnyInputStream(inputStream)
        inputStream.connect(to: self)
    }

    /// See InputStream.input
    func input(_ event: InputEvent<HTTPResponse>) {
        switch event {
        case .connect(let upstream):
            self.upstream = upstream
        case .next(let input):
            let promise = responseQueue.popLast()!
            promise.complete(input)
            if let onUpgrade = input.onUpgrade {
                do {
                    try onUpgrade.closure(.init(source), .init(sink), worker)
                } catch {
                    downstream?.error(error)
                }
            }
            update()
        case .error(let error): downstream?.error(error)
        case .close:
            for response in self.responseQueue {
                response.fail(HTTPError(identifier: "client-closed", reason: "The remote connection was closed (or failed to connect)"))
            }
            downstream?.close()
        }
    }
}

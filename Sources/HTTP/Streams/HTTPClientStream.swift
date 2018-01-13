import Async
import Bits

/// An inverse client stream accepting responses and outputting requests.
/// Used to implement HTTPClient. Should be kept internal
internal final class QueueStream<I, O>: Stream, ConnectionContext {
    /// See InputStream.Input
    typealias Input = I

    /// See OutputStream.Output
    typealias Output = O

    /// Queue of promised responses
    var inputQueue: [Promise<Input>]

    /// Queue of requests to be serialized
    var outputQueue: [Output]

    /// Accepts serialized requests
    var downstream: AnyInputStream<Output>?

    /// Serialized requests
    var remainingDownstreamRequests: UInt

    /// Parsed responses
    var upstream: ConnectionContext?

    /// Creates a new HTTP client stream
    init() {
        self.inputQueue = []
        self.outputQueue = []
        self.remainingDownstreamRequests = 0
    }

    public func queue(_ output: Output) -> Future<Input> {
        let promise = Promise(Input.self)
        self.outputQueue.append(output)
        self.inputQueue.append(promise)
        update()
        return promise.future
    }

    /// Updates the stream's state. If there are outstanding
    /// downstream requests, they will be fulfilled.
    func update() {
        guard remainingDownstreamRequests > 0 else {
            return
        }
        while let output = outputQueue.popLast() {
            remainingDownstreamRequests -= 1
            downstream?.next(output)
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
    func output<S>(to inputStream: S) where S : InputStream, S.Input == Output {
        downstream = AnyInputStream(inputStream)
        inputStream.connect(to: self)
    }

    /// See InputStream.input
    func input(_ event: InputEvent<Input>) {
        switch event {
        case .connect(let upstream):
            self.upstream = upstream
        case .next(let input):
            let promise = inputQueue.popLast()!
            promise.complete(input)
            update()
        case .error(let error): downstream?.error(error)
        case .close:
            downstream?.close()
        }
    }
}

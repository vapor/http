import Async
import Bits

/// Converts HTTPRequests to future HTTPResponses on the supplied event loop.
public protocol HTTPResponder {
    /// Returns a future response for the supplied request.
    func respond(to req: HTTPRequest, on worker: Worker) throws -> Future<HTTPResponse>
}

extension HTTPResponder {
    public func stream(
        upgradingTo byteStream: AnyStream<ByteBuffer, ByteBuffer>,
        on worker: Worker
    ) -> HTTPResponderStream<Self> {
        return .init(responder: self, byteStream: byteStream, on: worker)
    }
}

public final class HTTPResponderStream<Responder>: Stream where Responder: HTTPResponder {
    /// See `InputStream.Input`
    public typealias Input = HTTPRequest

    /// See `OutputStream.Output`
    public typealias Output = HTTPResponse

    /// Current downstream accepting our responses
    private var downstream: AnyInputStream<HTTPResponse>?

    /// The responder powering this stream.
    private let responder: Responder

    /// Byte stream to use for on upgrade.
    private let byteStream: AnyStream<ByteBuffer, ByteBuffer>

    /// Current event loop
    private let eventLoop: EventLoop

    /// Creates a new `HTTPResponderStream`
    internal init(responder: Responder, byteStream: AnyStream<ByteBuffer, ByteBuffer>, on worker: Worker) {
        self.responder = responder
        self.byteStream = byteStream
        self.eventLoop = worker.eventLoop
    }

    /// See `InputStream.input(_:)`
    public func input(_ event: InputEvent<HTTPRequest>) {
        guard let downstream = self.downstream else {
            ERROR("Unexpected nil downstream during HTTPResponderStream.input, ignoring event: \(event)")
            return
        }

        switch event {
        case .close: downstream.close()
        case .error(let error): downstream.error(error)
        case .next(let input, let nextRequest):
            do {
                let byteStream = self.byteStream
                let eventLoop = self.eventLoop

                try responder.respond(to: input, on: eventLoop).addAwaiter { res in
                    switch res {
                    case .error(let error): downstream.error(error)
                    case .expectation(let res):
                        if let onUpgrade = res.onUpgrade {
                            let receivedResponse = Promise(Void.self)
                            downstream.input(.next(res, receivedResponse))
                            receivedResponse.future.addAwaiter { rec in
                                do {
                                    switch rec {
                                    case .error(let error): downstream.error(error)
                                    case .expectation:
                                        try onUpgrade.closure(
                                            byteStream.outputStream,
                                            byteStream.inputStream,
                                            eventLoop
                                        )
                                        // Used to transfer the stream binding
                                        // FIXME: Feels like a hack
                                        nextRequest.complete()
                                    }
                                } catch {
                                    downstream.error(error)
                                }
                            }
                        } else {
                            downstream.input(.next(res, nextRequest))
                        }
                    }
                }
            } catch {
                downstream.error(error)
            }
        }
    }

    /// See `OutputStream.output(to:)`
    public func output<S>(to inputStream: S) where S : InputStream, HTTPResponderStream.Output == S.Input {
        downstream = .init(inputStream)
    }
}

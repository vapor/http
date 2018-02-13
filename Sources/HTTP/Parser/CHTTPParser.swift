import Async
import Bits
import CHTTP
import Dispatch
import Foundation

/// Internal CHTTP parser protocol
internal protocol CHTTPParser: HTTPParser where Input == ByteBuffer {
    /// Current downstream.
    var downstream: AnyInputStream<Output>? { get set }

    /// Holds the CHTTP parser's internal state.
    var chttp: CHTTPParserContext { get set }

    /// Converts the CHTTP parser results and body to HTTP message.
    func makeMessage(using body: HTTPBody) throws -> Output
}

/// MARK: CHTTPParser OutputStream

extension CHTTPParser {
    /// See `OutputStream.output(to:)`
    public func output<S>(to inputStream: S) where S: Async.InputStream, Self.Output == S.Input {
        downstream = .init(inputStream)
    }
}

/// MARK: CHTTPParser InputStream

extension CHTTPParser {
    /// See `InputStream.input(_:)`
    public func input(_ event: InputEvent<ByteBuffer>) {
        DEBUG("CHTTPParser.input(\(event))")
        guard let downstream = self.downstream else {
            ERROR("No downstream, ignoring input event: \(event)")
            return
        }

        switch event {
        case .close:
            chttp.close()
            switch chttp.bodyState {
            case .stream(let stream):
                stream.close()
                chttp.bodyState = .none
            default: downstream.close()
            }

        case .error(let error):
            downstream.error(error)
        case .next(let input, let ready):
            do {
                try handleNext(input, ready, downstream)
            } catch {
                downstream.error(error)
            }
        }
    }

    /// See `InputEvent.next`
    private func handleNext(_ buffer: ByteBuffer, _ ready: Promise<Void>, _ downstream: AnyInputStream<Output>) throws {
        DEBUG("CHTTPParser.handle() [state: \(chttp.state)]")
        switch chttp.state {
        case .parsing:
            /// Parse the message using the CHTTP parser.
            try chttp.execute(from: buffer)

            /// Copies raw header data from the buffer
            chttp.copyHeaders(from: buffer)

            /// Check if we have received all of the messages headers
            if chttp.headersComplete {
                /// Either streaming or static will be decided
                let body: HTTPBody

                /// The message is ready to move downstream, check to see
                /// if we already have the HTTPBody in its entirety
                if chttp.messageComplete {
                    switch chttp.bodyState {
                    case .buffer(let buffer): body = HTTPBody(storage: .buffer(buffer))
                    case .data(let data): body = HTTPBody(storage: .data(data))
                    case .none: body = HTTPBody()
                    case .stream:
                        ERROR("Using empty body. Unexpected state: \(chttp.bodyState)")
                        body = HTTPBody()
                    }
                    let message = try makeMessage(using: body)
                    downstream.input(.next(message, ready))
                    chttp.reset()
                } else {
                    // Convert body to a stream
                    let stream = CHTTPBodyStream()
                    switch chttp.bodyState {
                    case .buffer(let buffer): stream.push(buffer)
                    case .data(let data): data.withByteBuffer { stream.push($0) }
                    case .none: stream.push(ByteBuffer(start: nil, count: 0))
                    case .stream(_): ERROR("Ignoring existing stream. Unexpected state: \(chttp.bodyState)")
                    }
                    stream.flush(ready)
                    chttp.bodyState = .stream(stream)
                    body = HTTPBody(stream: .init(stream)) {
                        return self.chttp.headers?[.contentLength].flatMap(Int.init)
                    }
                    let message = try makeMessage(using: body)
                    let nextMessagePromise = Promise(Void.self)
                    downstream.input(.next(message, nextMessagePromise))
                    chttp.state = .streaming(nextMessagePromise.future)
                }
            } else {
                /// Headers not complete, request more input
                ready.complete()
            }
        case .streaming(let nextMessageFuture):
            /// Parse the message using the CHTTP parser.
            try chttp.execute(from: buffer)

            if chttp.messageComplete {
                /// Close the body stream now
                chttp.state = .streamingClosed(nextMessageFuture)

                switch chttp.bodyState {
                case .stream(let stream):
                    stream.flush(ready)
                    stream.close()
                default:
                    ERROR("Unexpected state: \(chttp.bodyState)")
                    ready.complete()
                }
            } else {
                /// Close the body stream now
                switch chttp.bodyState {
                case .none, .buffer, .data:
                    ERROR("Unexpected state: \(chttp.bodyState)")
                    ready.complete()
                case .stream(let s): s.flush(ready)
                }
            }
        case .streamingClosed(let nextMessageFuture):
            chttp.reset()
            nextMessageFuture.map(to: Void.self) {
                return try self.handleNext(buffer, ready, downstream)
            }.catch { error in
                downstream.error(error)
                ready.complete()
            }
        }
    }
}

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
        guard let downstream = self.downstream else {
            fatalError("Unexpected `nil` downstream on CHTTPParser.input(close)")
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
                    case .none: body = HTTPBody()
                    case .stream: fatalError("Illegal state")
                    case .readyStream: fatalError("Illegal state")
                    }
                    let message = try makeMessage(using: body)
                    downstream.input(.next(message, ready))
                    chttp.reset()
                } else {
                    // Convert body to a stream
                    let stream = CHTTPBodyStream()
                    switch chttp.bodyState {
                    case .buffer(let buffer): stream.push(buffer, ready)
                    case .none: stream.push(ByteBuffer(start: nil, count: 0), ready)
                    case .stream: fatalError("Illegal state")
                    case .readyStream: fatalError("Illegal state")
                    }
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
            let stream: CHTTPBodyStream

            /// Close the body stream now
            switch chttp.bodyState {
            case .none: fatalError("Illegal state")
            case .buffer: fatalError("Illegal state")
            case .readyStream: fatalError("Illegal state")
            case .stream(let s):
                stream = s
                // replace body state w/ new ready
                chttp.bodyState = .readyStream(s, ready)
            }

            /// Parse the message using the CHTTP parser.
            try chttp.execute(from: buffer)

            if chttp.messageComplete {
                /// Close the body stream now
                stream.close()
                chttp.state = .streamingClosed(nextMessageFuture)
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

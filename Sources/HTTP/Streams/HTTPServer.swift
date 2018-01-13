import Async
import Bits
import class Foundation.Thread
import TCP

//#if os(Linux)
//    import OpenSSL
//#else
//    import AppleTLS
//#endif

/// Converts an output stream of byte streams (meta stream) to
/// a stream of HTTP clients. These incoming clients are then
/// streamed to the responder supplied during `.start()`.
public final class HTTPServer {
    /// Handles any uncaught errors
    public typealias ErrorHandler = (Error) -> ()

    /// Sets this servers error handler.
    public var onError: ErrorHandler?

    /// Create a new HTTP server with the supplied accept stream.
    public init<AcceptStream>(acceptStream: AcceptStream, worker: Worker, responder: HTTPResponder)
        where AcceptStream: OutputStream, AcceptStream.Output: ByteStreamRepresentable
    {
        /// set up the server stream
        acceptStream.drain { client, upstream in
            let serializerStream = HTTPResponseSerializer().stream(on: worker)
            let parserStream = HTTPRequestParser().stream(on: worker)

            let source = client.source(on: worker)
            let sink = client.sink(on: worker)
            source
                .stream(to: parserStream)
                .stream(to: responder.stream(on: worker).stream())
                .map(to: HTTPResponse.self) { response in
                    /// map the responder adding http upgrade support
                    if let onUpgrade = response.onUpgrade {
                        do {
                            try onUpgrade.closure(.init(source), .init(sink), worker)
                        } catch {
                            self.onError?(error)
                        }
                    }
                    return response
                }
                .stream(to: serializerStream)
                .output(to: sink)
        }.catch { err in
            self.onError?(err)
        }.finally {
            // closed
        }.request(count: .max)
    }
}

/// Representable by an associated byte stream.
public protocol ByteStreamRepresentable {
    /// The associated byte stream type.
    associatedtype SourceStream
        where
            SourceStream: OutputStream,
            SourceStream.Output == ByteBuffer

    associatedtype SinkStream
        where
            SinkStream: InputStream,
            SinkStream.Input == ByteBuffer

    /// Convert to the associated byte stream.
    func source(on worker: Worker) -> SourceStream
    func sink(on worker: Worker) -> SinkStream
}

//#if os(Linux)
//    extension OpenSSLSocket: ByteStreamRepresentable {}
//#else
//    extension AppleTLSSocket: ByteStreamRepresentable {}
//#endif

extension TCPClient: ByteStreamRepresentable {
    /// See ByteStreamRepresentable.source
    public func source(on eventLoop: Worker) -> SocketSource<TCPSocket> {
        return socket.source(on: eventLoop.eventLoop)
    }

    /// See ByteStreamRepresentable.sink
    public func sink(on eventLoop: Worker) -> SocketSink<TCPSocket> {
        return socket.sink(on: eventLoop.eventLoop)
    }
}

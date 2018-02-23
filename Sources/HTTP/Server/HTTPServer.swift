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
    public init<AcceptStream, Responder>(acceptStream: AcceptStream, worker: Worker, responder: Responder)
        where AcceptStream: OutputStream, AcceptStream.Output: ByteStream, Responder: HTTPResponder
    {
        /// set up the server stream
        acceptStream.drain { client in
            let serializerStream = HTTPResponseSerializer()
            let parserStream = HTTPRequestParser()

            client
                .stream(to: parserStream)
                .stream(to: responder.stream(upgradingTo: .init(client), on: worker))
                .stream(to: serializerStream)
                .output(to: client)
        }.catch { err in
            self.onError?(err)
        }.finally {
            // closed
        }
    }
}

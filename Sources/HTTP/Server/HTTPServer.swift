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
        where AcceptStream: OutputStream, AcceptStream.Output: ByteStream
    {
        /// set up the server stream
        acceptStream.drain { client in
            let serializerStream = HTTPResponseSerializer().stream(on: worker)
            let parserStream = HTTPRequestParser()

            client
                .stream(to: parserStream)
                .stream(to: responder.stream(on: worker).stream())
                .map(to: HTTPResponse.self) { response in
                    /// map the responder adding http upgrade support
                    if let onUpgrade = response.onUpgrade {
                        do {
                            try onUpgrade.closure(.init(client), .init(client), worker)
                        } catch {
                            self.onError?(error)
                        }
                    }
                    return response
                }
                .stream(to: serializerStream)
                .output(to: client)
        }.catch { err in
            self.onError?(err)
        }.finally {
            // closed
        }
    }
}

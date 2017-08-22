import Core
import Dispatch

/// Capable of responding to a request.
public protocol Responder {
    func respond(to req: Request) throws -> Future<Response>
}

extension Responder {
    /// Creates a stream from this responder capable of being
    /// added to a server or client stream.
    public func makeStream(on queue: DispatchQueue) -> ResponderStream {
        return ResponderStream(
            responder: self,
            queue: queue
        )
    }
}

/// A stream containing an HTTP responder.
public final class ResponderStream: Core.Stream {
    /// See InputStream.Input
    public typealias Input = Request

    /// See OutputStream.Output
    public typealias Output = Response

    /// See BaseStream.errorStream
    public var errorStream: ErrorHandler?

    // See BaseStream.outputStream
    public var outputStream: OutputHandler?

    /// The responder
    let responder: Responder

    /// The queue on which responses will be awaited
    let queue: DispatchQueue

    /// Create a new response stream.
    /// The responses will be awaited on the supplied queue.
    public init(responder: Responder, queue: DispatchQueue) {
        self.responder = responder
        self.queue = queue
    }

    /// Handle incoming requests.
    public func inputStream(_ input: Request) {
        do {
            // dispatches the incoming request to the responder.
            // the response is awaited on the responder stream's queue.
            try responder.respond(to: input).then(asynchronously: queue) { res in
                self.outputStream?(res)
            }
        } catch {
            errorStream?(error)
        }
    }
}


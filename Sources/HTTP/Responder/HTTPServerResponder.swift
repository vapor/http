import NIO

/// Capable of responding to HTTP requests received by an `HTTPServer`.
public protocol HTTPServerResponder {
    /// Responds to an incoming `HTTPRequest`.
    ///
    /// - parameters:
    ///     - request: `HTTPRequest` received by the `HTTPServer`.
    ///     - worker: `EventLoop` to perform async work on.
    /// - returns: Future `HTTPResponse` to send back to peer.
    func respond(to request: HTTPRequest, on eventLoop: EventLoop) -> EventLoopFuture<HTTPResponse>
}

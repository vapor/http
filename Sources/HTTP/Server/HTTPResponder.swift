import NIO

/// Capable of responding to incoming `HTTPRequest`s.
public protocol HTTPResponder {
    /// Responds to an incoming `HTTPRequest`.
    ///
    /// - parameters:
    ///     - req: Incoming `HTTPRequest` to respond to.
    /// - returns: Future `HTTPResponse` to send back.
    func respond(to req: HTTPRequest) -> EventLoopFuture<HTTPResponse>
}

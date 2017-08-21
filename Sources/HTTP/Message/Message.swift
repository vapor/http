/// An HTTP message.
public protocol Message: class, Codable {
    /// The HTTP version of this message.
    var version: Version { get set }
    /// The HTTP headers.
    var headers: Headers { get set }
    /// The message body.
    var body: Body { get set }
}

extension Message {
    /// Updates the content length header to the current
    /// body length. This should be called whenever the
    /// body is modified.
    internal func updateContentLength() {
        headers[.contentLength] = body.data.count.description
    }
}

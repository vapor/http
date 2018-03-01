/// An HTTP response from a server back to the client.
public struct HTTPResponse: HTTPMessage {
    /// The HTTP response status.
    public var status: HTTPResponseStatus

    /// The HTTP version that corresponds to this response.
    public var version: HTTPVersion

    /// The HTTP headers on this response.
    public var headers: HTTPHeaders

    /// The http body
    public var body: HTTPBody?

    /// This request's event loop.
    public var eventLoop: EventLoop

    /// Creates a new HTTP Request
    public init(
        status: HTTPResponseStatus = .ok,
        version: HTTPVersion = .init(major: 1, minor: 1),
        headers: HTTPHeaders = .init(),
        body: HTTPBody? = nil,
        on worker: Worker
    ) {
        self.status = status
        self.version = version
        self.headers = headers
        self.body = body
        self.eventLoop = worker.eventLoop
    }
}

extension HTTPResponse {
    /// See `CustomStringConvertible.description
    public var description: String {
        var desc: [String] = []
        desc.append("HTTP/\(version.major).\(version.minor) \(status.code) \(status.reasonPhrase)")
        desc.append(headers.debugDescription)
        desc.append(body?.description ?? "<no body>")
        return desc.joined(separator: "\n")
    }
}

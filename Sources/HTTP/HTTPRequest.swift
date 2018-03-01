/// An HTTP request from a client to a server.
public struct HTTPRequest: HTTPMessage {
    /// The HTTP method for this request.
    public var method: HTTPMethod

    /// The URI used on this request.
    public var uri: String

    /// The version for this HTTP request.
    public var version: HTTPVersion

    /// The header fields for this HTTP request.
    public var headers: HTTPHeaders

    /// The http body
    public var body: HTTPBody?

    /// This request's event loop.
    public var eventLoop: EventLoop

    /// Creates a new HTTP Request
    public init(
        method: HTTPMethod = .GET,
        uri: String = "/",
        version: HTTPVersion = .init(major: 1, minor: 1),
        headers: HTTPHeaders = .init(),
        body: HTTPBody? = nil,
        on worker: Worker
    ) {
        self.method = method
        self.uri = uri
        self.version = version
        self.headers = headers
        self.body = body
        self.eventLoop = worker.eventLoop
    }
}

extension HTTPRequest {
    /// See `CustomStringConvertible.description
    public var description: String {
        var desc: [String] = []
        desc.append("\(method) \(uri) HTTP/\(version.major).\(version.minor)")
        desc.append(headers.debugDescription)
        desc.append(body?.description ?? "<no body>")
        return desc.joined(separator: "\n")
    }
}

/// An HTTP response from a server back to the client.
public struct HTTPResponse: HTTPMessage {
    /// The HTTP response status.
    public var status: HTTPResponseStatus

    /// The HTTP version that corresponds to this response.
    public var version: HTTPVersion

    /// The HTTP headers on this response.
    public var headers: HTTPHeaders

    /// The http body.
    /// Updating this property will also update the associated transport headers.
    public var body: HTTPBody {
        didSet {
            updateTransportHeaders()
        }
    }

    /// Creates a new HTTP Response.
    public init(
        status: HTTPResponseStatus = .ok,
        version: HTTPVersion = .init(major: 1, minor: 1),
        headers: HTTPHeaders = .init(),
        body: HTTPBody = .init()
    ) {
        self.status = status
        self.version = version
        self.headers = headers
        self.body = body
        updateTransportHeaders()
    }

    /// Creates a new HTTPResponse without sanitizing headers.
    internal init(
        status: HTTPResponseStatus,
        version: HTTPVersion,
        headersNoUpdate headers: HTTPHeaders,
        body: HTTPBody
    ) {
        self.status = status
        self.version = version
        self.headers = headers
        self.body = body
    }
}

extension HTTPResponse {
    /// See `CustomStringConvertible.description`
    public var description: String {
        var desc: [String] = []
        desc.append("HTTP/\(version.major).\(version.minor) \(status.code) \(status.reasonPhrase)")
        desc.append(headers.debugDescription)
        desc.append(body.description)
        return desc.joined(separator: "\n")
    }
}

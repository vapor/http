import Foundation

/// HTTP request.
public final class Request: Message {
    /// HTTP requests have a method, like GET or POST
    public var method: Method

    /// This is usually just a path like `/foo` but
    /// may be a full URI in the case of a proxy
    public var uri: URI

    /// See Message.version
    public var version: Version

    /// See Message.headers
    public var headers: Headers

    /// See Message.body
    public var body: Body {
        didSet { updateContentLength() }
    }

    /// Create a new HTTP request.
    public init(
        method: Method = .get,
        uri: URI = URI(),
        version: Version = Version(major: 1, minor: 1),
        headers: Headers = Headers(),
        body: Body = Body()
    ) {
        self.method = method
        self.uri = uri
        self.version = version
        self.headers = headers
        self.body = body
        updateContentLength()
    }
}

// MARK: Convenience

extension Request {
    /// Create a new HTTP request using something BodyRepresentable.
    public convenience init(
        method: Method = .get,
        uri: URI = URI(),
        version: Version = Version(major: 1, minor: 1),
        headers: Headers = Headers(),
        body: BodyRepresentable
    ) throws {
        try self.init(method: method, uri: uri, version: version, headers: headers, body: body.makeBody())
    }
}

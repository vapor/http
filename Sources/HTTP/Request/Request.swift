import Foundation

public final class Request: Message {
    public var method: Method
    public var uri: URI
    public var version: Version
    public var headers: Headers
    public var body: Body {
        didSet { updateContentLength() }
    }

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

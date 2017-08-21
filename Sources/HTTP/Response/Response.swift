import Foundation

/// HTTP response.
public final class Response: Message {
    /// See Message.version
    public var version: Version

    /// HTTP response status code.
    public var status: Status

    /// See Message.headers
    public var headers: Headers

    /// See Message.body
    public var body: Body {
        didSet { updateContentLength() }
    }

    /// Create a new HTTP response.
    public init(
        version: Version = Version(major: 1, minor: 1),
        status: Status = .ok,
        headers: Headers = Headers(),
        body: Body = Body()
    ) {
        self.version = version
        self.status = status
        self.headers = headers
        self.body = body
        updateContentLength()
    }
}

extension Response {
    /// Create a new HTTP response using something BodyRepresentable.
    public convenience init(
        version: Version = Version(major: 1, minor: 1),
        status: Status = .ok,
        headers: Headers = Headers(),
        body: BodyRepresentable
    ) throws {
        try self.init(version: version, status: status, headers: headers, body: body.makeBody())
    }
}

/// Can be converted from a response.
public protocol ResponseInitializable {
    init(response: Response) throws
}

/// Can be converted to a response
public protocol ResponseRepresentable {
    func makeResponse() throws -> Response
}

/// Can be converted from and to a response
public typealias ResponseConvertible = ResponseInitializable & ResponseRepresentable

// MARK: Response Conformance

extension Response: ResponseRepresentable {
    public func makeResponse() throws -> Response {
        return self
    }
}

import Foundation

public final class Response: Message {
    public var version: Version
    public var status: Status
    public var headers: Headers
    public var body: Body {
        didSet { updateContentLength() }
    }

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
    public convenience init(
        version: Version = Version(major: 1, minor: 1),
        status: Status = .ok,
        headers: Headers = Headers(),
        body: BodyRepresentable
    ) throws {
        try self.init(version: version, status: status, headers: headers, body: body.makeBody())
    }
}

/// Can be representable as a response
public protocol ResponseRepresentable {
    func makeResponse() throws -> Response
}

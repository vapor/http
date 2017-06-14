import Transport

// So common we simplify it

import URI

public final class Response: Message {
    public var version: Version
    public var status: Status
    public var headers: [HeaderKey: String]
    public var body: Body
    public var storage: [String: Any]
    public var onComplete: ((DuplexStream) throws -> Void)?
    
    public init(
        version: Version = Version(major: 1, minor: 1),
        status: Status,
        headers: [HeaderKey: String] = [:],
        body: Body = .data([])
    ) {
        self.status = status
        self.version = version
        self.headers = headers
        self.body = body
        self.storage = [:]
        self.onComplete = nil
    }
}

extension Response {
    /// Creates a Response with a body of Bytes.
    public convenience init<S: Sequence>(
        version: Version = Version(major: 1, minor: 1),
        status: Status,
        headers: [HeaderKey: String] = [:],
        body: S
    )
        where S.Iterator.Element == Byte
    {
        let body = Body(body)
        self.init(version: version, status: status, headers: headers, body: body)
    }
}



extension Response {
    /// Creates a Response with a BodyRepresentable Body
    public convenience init(
        version: Version = Version(major: 1, minor: 1),
        status: Status,
        headers: [HeaderKey: String] = [:],
        body: BodyRepresentable
    ) {
        let body = body.makeBody()
        self.init(
            version: version,
            status: status,
            headers: headers,
            body: body
        )
        self.status = status
    }
}

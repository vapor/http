import Transport

// So common we simplify it

public final class Response: Message {
    public let version: Version
    public let status: Status

    // MARK: Post Serialization

    public var onComplete: ((DuplexStream) throws -> Void)? // FIXME: generic

    public init(
        version: Version = Version(major: 1, minor: 1),
        status: Status = .ok,
        headers: [HeaderKey: String] = [:],
        body: Body = .data([]),
        peerAddress: PeerAddress? = nil
    ) {
        self.version = version
        self.status = status


        let statusLine = "HTTP/\(version.major).\(version.minor) \(status.statusCode) \(status.reasonPhrase)"
        super.init(startLine: statusLine, headers: headers, body: body, peerAddress: peerAddress)
    }

    public convenience required init(
        startLineComponents: (BytesSlice, BytesSlice, BytesSlice),
        headers: [HeaderKey: String],
        body: Body,
        peerAddress: PeerAddress?
    ) throws {
        let (httpVersionSlice, statusCodeSlice, reasonPhrase) = startLineComponents
        let version = try Version.makeParsed(with: httpVersionSlice)
        guard let statusCode = Int(statusCodeSlice.makeString()) else {
            throw MessageError.invalidStartLine
        }
        let status = Status(statusCode: statusCode, reasonPhrase: reasonPhrase.makeString())

        self.init(version: version, status: status, headers: headers, body: body, peerAddress: peerAddress)
    }
}

extension Response {
    /**
        Creates a redirect response.
     
        Set permanently to 'true' to allow caching to automatically redirect from browsers.
        Defaulting to non-permanent to prevent unexpected caching.
    */
    public convenience init(headers: [HeaderKey: String] = [:], redirect location: String, permanently: Bool = false) {
        var headers = headers
        headers["Location"] = location
        // .found == 302 and is commonly used for temporarily moved
        let status: Status = permanently ? .movedPermanently : .found
        self.init(status: status, headers: headers)
    }
}

extension Response {
    /**
        Creates a Response with a body of Bytes.
    */
    public convenience init
        <S: Sequence>
        (version: Version = Version(major: 1, minor: 1), status: Status = .ok, headers: [HeaderKey: String] = [:], body: S)
        where S.Iterator.Element == Byte
    {
        let body = Body(body)
        self.init(version: version, status: status, headers: headers, body: body, peerAddress: nil)
    }
}



extension Response {
    /**
        Creates a Response with a BodyRepresentable Body
    */
    public convenience init(
        version: Version = Version(major: 1, minor: 1),
        status: Status = .ok,
        headers: [HeaderKey: String] = [:],
        body: BodyRepresentable
    ) {
        let body = body.makeBody()
        self.init(version: version, status: status, headers: headers, body: body, peerAddress: nil)
    }
}

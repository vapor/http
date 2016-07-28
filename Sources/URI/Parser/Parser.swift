import Core

public final class URIParser: StaticDataBuffer {

    public enum Error: Swift.Error {
        case invalidPercentEncoding
        case unsupportedURICharacter(Byte)
    }

    // If we have authority, we should also have scheme?
    let existingHost: Bytes?

    /**
        The most common form of Request-URI is that used to identify a
        resource on an origin server or gateway. In this case the absolute
        path of the URI MUST be transmitted (see section 3.2.1, abs_path) as
        the Request-URI, and the network location of the URI (authority) MUST
        be transmitted in a Host header field. For example, a client wishing
        to retrieve the resource above directly from the origin server would
        create a TCP connection to port 80 of the host "www.w3.org" and send
        the lines:

        GET /pub/WWW/TheProject.html HTTP/1.1
        Host: www.w3.org

        If host exists, and scheme exists, use those
    */
    public init(bytes: Bytes, existingHost: String? = nil) {
        self.existingHost = existingHost?.bytes
        super.init(bytes: bytes)
    }

    // MARK: Paser URI

    /**
        Main parsing function
    */
    internal func parse() throws -> URI {
        let (schemeBytes, authorityBytes, pathBytes, queryBytes, fragmentBytes) = try parseComponents()
        let (usernameBytes, infoBytes, hostBytes, portBytes) = try parse(authority: authorityBytes)

        /*
            ***** [WARNING] *****

            do NOT attempt to percent decode before THIS point
        */
        let scheme = try schemeBytes.percentDecodedString()
        let username = try usernameBytes?.percentDecodedString()
        let info = try infoBytes?.percentDecodedString()

        let userInfo: URI.UserInfo?
        if let username = username, !username.isEmpty {
            userInfo = URI.UserInfo(
                username: username,
                info: info
            )
        } else {
            userInfo = nil
        }


        // port MUST convert to string, THEN to Int
        let host = try hostBytes.percentDecodedString()
        let portString = try portBytes?.percentDecodedString() ?? ""
        let port = Int(portString)
        let path = try pathBytes.percentDecodedString()
        let query = try queryBytes?.percentDecodedString()
        let fragment = try fragmentBytes?.percentDecodedString()
        let uri = URI(
            scheme: scheme,
            userInfo: userInfo,
            host: host,
            port: port,
            path: path,
            query: query,
            fragment: fragment
        )

        return uri
    }

    // MARK: Component Parse

    private func parseComponents() throws -> (
        scheme: [Byte],
        authority: [Byte],
        path: [Byte],
        query: [Byte]?,
        fragment: [Byte]?
    ) {
        // ordered calls
        let scheme = try parseScheme()
        let authority = try parseAuthority() ?? []
        let path = try parsePath()
        let query = try parseQuery()
        let fragment = try parseFragment()

        return (
            scheme,
            authority,
            path,
            query,
            fragment
        )
    }

    /**
        Filter out white space and throw on invalid characters
    */
    public override func next() throws -> Byte? {
        guard let next = try super.next() else { return nil }
        guard !next.isWhitespace else { return try self.next() }
        guard next.isValidUriCharacter else { throw Error.unsupportedURICharacter(next) }
        return next
    }
}

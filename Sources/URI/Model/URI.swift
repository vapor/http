import Transport

/*
     https://tools.ietf.org/html/rfc3986#section-3
 
     URI         = scheme ":" hier-part [ "?" query ] [ "#" fragment ]

     The following are two example URIs and their component parts:

     foo://example.com:8042/over/there?name=ferret#nose
     \_/   \______________/\_________/ \_________/ \__/
     |           |            |            |        |
     scheme     authority       path        query   fragment
     |   _____________________|__
     / \ /                        \
     urn:example:animal:ferret:nose
*/
public struct URI {
    // https://tools.ietf.org/html/rfc3986#section-3.1
    public var scheme: String

    // https://tools.ietf.org/html/rfc3986#section-3.2.1
    public var userInfo: UserInfo?
    // https://tools.ietf.org/html/rfc3986#section-3.2.2
    public var hostname: String
    // https://tools.ietf.org/html/rfc3986#section-3.2.3
    public var port: Port?

    // https://tools.ietf.org/html/rfc3986#section-3.3
    public var path: String

    // https://tools.ietf.org/html/rfc3986#section-3.4
    public var query: String?

    // https://tools.ietf.org/html/rfc3986#section-3.5
    public var fragment: String?

    /// Creates a new URI
    public init(
        scheme: String = "",
        userInfo: UserInfo? = nil,
        hostname: String,
        port: Port? = nil,
        path: String = "",
        query: String? = nil,
        fragment: String? = nil
    ) {
        let scheme = scheme.lowercased()
        self.scheme = scheme
        self.userInfo = userInfo
        self.hostname = hostname.lowercased()
        self.port = port ?? URI.defaultPorts[scheme]
        self.path = path
        self.query = query
        self.fragment = fragment
    }
}

extension URI {
    /*
         https://tools.ietf.org/html/rfc3986#section-3.2.1
    */
    public struct UserInfo {
        public let username: String
        public let info: String?

        public init(username: String, info: String? = nil) {
            self.username = username
            self.info = info
        }
    }
}

extension URI.UserInfo: CustomStringConvertible {
    public var description: String {
        var d = ""
        d += username
        if let info = info {
            d += ":\(info)"
        }
        return d
    }
}

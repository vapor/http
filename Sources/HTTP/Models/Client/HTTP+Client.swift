public enum HTTPClientError: Swift.Error {
    case invalidRequestHost
    case invalidRequestScheme
    case invalidRequestPort
    case unableToConnect
    case userInfoNotAllowedOnHTTP
}

public final class HTTPClient<ClientStreamType: ClientStream>: Client {
    public let scheme: String
    public let host: String
    public let port: Int
    public let securityLayer: SecurityLayer

    public let stream: Stream

    public init(scheme: String, host: String, port: Int, securityLayer: SecurityLayer) throws {
        self.scheme = scheme
        self.host = host
        self.port = port
        self.securityLayer = securityLayer

        let client = try ClientStreamType(host: host, port: port, securityLayer: securityLayer)
        let stream = try client.connect()
        self.stream = stream
    }

    public func respond(to request: HTTPRequest) throws -> HTTPResponse {
        try assertValid(request)
        guard !stream.closed else { throw HTTPClientError.unableToConnect }
        let buffer = StreamBuffer(stream)

        /*
             A client MUST send a Host header field in all HTTP/1.1 request
             messages.  If the target URI includes an authority component, then a
             client MUST send a field-value for Host that is identical to that
             authority component, excluding any userinfo subcomponent and its "@"
             delimiter (Section 2.7.1).  If the authority component is missing or
             undefined for the target URI, then a client MUST send a Host header
             field with an empty field-value.
        */
        request.headers["Host"] = host

        let serializer = HTTPSerializer<HTTPRequest>(stream: buffer)
        try serializer.serialize(request)

        let parser = HTTPParser<HTTPResponse>(stream: buffer)
        let response = try parser.parse()

        try buffer.flush()

        return response
    }

    private func assertValid(_ request: HTTPRequest) throws {
        if request.uri.host.isEmpty {
            guard request.uri.host == host else { throw HTTPClientError.invalidRequestHost }
        }

        if request.uri.scheme.isEmpty {
            guard request.uri.scheme.securityLayer == securityLayer else { throw HTTPClientError.invalidRequestScheme }
        }

        if let requestPort = request.uri.port {
            guard requestPort == port else { throw HTTPClientError.invalidRequestPort }
        }

        guard request.uri.userInfo == nil else {
            /*
                 Userinfo (i.e., username and password) are now disallowed in HTTP and
                 HTTPS URIs, because of security issues related to their transmission
                 on the wire.  (Section 2.7.1)
            */
            throw HTTPClientError.userInfoNotAllowedOnHTTP
        }
    }
}

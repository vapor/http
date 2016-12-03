import Transport

public enum ClientError: Swift.Error {
    case invalidRequestHost
    case invalidRequestScheme
    case invalidRequestPort
    case unableToConnect
    case userInfoNotAllowedOnHTTP
}

public typealias BasicClient = Client<TCPClientStream, Serializer<Request>, Parser<Response>>

let VERSION = "0.9.0"

public final class Client<
    ClientStreamType: ClientStream,
    SerializerType: TransferSerializer,
    ParserType: TransferParser>
    : ClientProtocol
    where ParserType.MessageType == Response, SerializerType.MessageType == Request
{
    public typealias Serializer = SerializerType
    public typealias Parser = ParserType

    public let scheme: String
    public let host: String
    public let port: Int
    public let securityLayer: SecurityLayer
    public let middleware: [Middleware]

    public private(set) var stream: Stream

    public private(set) var responder: Responder!

    public init(
        scheme: String,
        host: String,
        port: Int = 80,
        securityLayer: SecurityLayer = .none,
        middleware: [Middleware] = []
    ) throws {
        self.scheme = scheme
        self.host = host
        self.port = port
        self.securityLayer = securityLayer
        self.middleware = type(of: self).defaultMiddleware + middleware

        let client = try ClientStreamType(host: host, port: port, securityLayer: securityLayer)
        var stream = try client.connect()
        self.stream = stream

        let handler = Request.Handler { [weak self] request in
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
            request.headers["User-Agent"] = "App (Swift) VaporEngine/\(VERSION)"
            
            let performRequest = { () -> Response in
                let buffer = StreamBuffer(stream)
                let serializer = SerializerType(stream: buffer)
                try serializer.serialize(request)
                
                let parser = ParserType(stream: buffer)
                let response = try parser.parse()
                
                try buffer.flush()
                
                return response
            }
            
            do {
                return try performRequest()
            }
            catch ParserError.streamEmpty {
                // Try once more with a new connection
                let client = try ClientStreamType(host: host, port: port, securityLayer: securityLayer)
                stream = try client.connect()
                self?.stream = stream
                
                return try performRequest()
            }
            catch {
                throw error
            }
        }

        // add middleware
        responder = self.middleware.chain(to: handler)
    }
    
    deinit {
        try? stream.close()
    }

    public func respond(to request: Request) throws -> Response {
        try assertValid(request)
        guard !stream.closed else { throw ClientError.unableToConnect }

        return try responder.respond(to: request)
    }
}

extension ClientProtocol {
    internal func assertValid(_ request: Request) throws {
        if request.uri.host.isEmpty {
            guard request.uri.host == host else {
                throw ClientError.invalidRequestHost
            }
        }

        if request.uri.scheme.isEmpty {
            guard request.uri.scheme.securityLayer.isSecure == securityLayer.isSecure else {
                throw ClientError.invalidRequestScheme
            }
        }

        if let requestPort = request.uri.port {
            guard requestPort == port else { throw ClientError.invalidRequestPort }
        }

        guard request.uri.userInfo == nil else {
            /*
                 Userinfo (i.e., username and password) are now disallowed in HTTP and
                 HTTPS URIs, because of security issues related to their transmission
                 on the wire.  (Section 2.7.1)
            */
            throw ClientError.userInfoNotAllowedOnHTTP
        }
    }
}

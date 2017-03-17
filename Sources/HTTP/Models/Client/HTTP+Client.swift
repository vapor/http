import Transport
import Sockets

public enum ClientError: Swift.Error {
    case invalidRequestHost
    case invalidRequestScheme
    case invalidRequestPort
    case unableToConnect
    case userInfoNotAllowedOnHTTP
    case missingHost
}

public typealias TCPClient = BasicClient<
    TCPInternetSocket,
    Serializer<Request, StreamBuffer<TCPInternetSocket>>,
    Parser<Response, StreamBuffer<TCPInternetSocket>>
>

import TLS

public typealias TLSTCPClient = BasicClient<
    TLS.ClientSocket,
    Serializer<Request, StreamBuffer<TLS.ClientSocket>>,
    Parser<Response, StreamBuffer<TLS.ClientSocket>>
>

public final class BasicClient<
    ClientStreamType: ClientStream,
    Serializer: TransferSerializer,
    Parser: TransferParser
>: Client where
    Parser.MessageType == Response,
    Serializer.MessageType == Request,
    Parser.StreamType == StreamBuffer<ClientStreamType>,
    Serializer.StreamType == StreamBuffer<ClientStreamType>
{
    public typealias StreamType = ClientStreamType

    public let middleware: [Middleware]
    public let stream: StreamType

    private let responder: Responder

    public init(
        _ stream: StreamType,
        _ middleware: [Middleware] = []
    ) throws {
        self.stream = stream
        self.middleware = type(of: self).defaultMiddleware + middleware
        try stream.connect()

        let handler = Request.Handler { request in
            ///  client MUST send a Host header field in all HTTP/1.1 request
            /// messages.  If the target URI includes an authority component, then a
            /// client MUST send a field-value for Host that is identical to that
            /// authority component, excluding any userinfo subcomponent and its "@"
            /// delimiter (Section 2.7.1).  If the authority component is missing or
            /// undefined for the target URI, then a client MUST send a Host header
            /// field with an empty field-value.
            request.headers["Host"] = stream.hostname
            request.headers["User-Agent"] = userAgent

            let buffer = StreamBuffer<StreamType>(stream)
            let serializer = Serializer(stream: buffer)
            try serializer.serialize(request)

            let parser = Parser(stream: buffer)
            let response = try parser.parse()

            response.peerAddress = parser.parsePeerAddress(
                from: stream,
                with: response.headers
            )

            try buffer.flush()

            return response
        }

        // add middleware
        responder = self.middleware.chain(to: handler)
    }
    
    deinit {
        try? stream.close()
    }

    public func respond(to request: Request) throws -> Response {
        try assertValid(request)
        guard !stream.isClosed else { throw ClientError.unableToConnect }

        return try responder.respond(to: request)
    }
}

let VERSION = "2"
public var userAgent = "App (Swift) VaporEngine/\(VERSION)"


extension Client where StreamType: InternetStream {
    internal func assertValid(_ request: Request) throws {
        if request.uri.hostname.isEmpty {
            guard request.uri.hostname == stream.hostname else {
                throw ClientError.invalidRequestHost
            }
        }

        if request.uri.scheme.isEmpty {
            guard request.uri.scheme == stream.scheme else {
                throw ClientError.invalidRequestScheme
            }
        }

        if let requestPort = request.uri.port {
            guard requestPort == stream.port else { throw ClientError.invalidRequestPort }
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

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
    StreamType: ClientStream,
    Serializer: TransferSerializer,
    Parser: TransferParser
>: Client where
    Parser.MessageType == Response,
    Serializer.MessageType == Request,
    Parser.StreamType == StreamBuffer<StreamType>,
    Serializer.StreamType == StreamBuffer<StreamType>
{
    // public let middleware: [Middleware]
    public let stream: StreamType

    public var scheme: String {
        return stream.scheme
    }

    public var hostname: String {
        return stream.hostname
    }

    public var port: Port {
        return stream.port
    }

    public init(_ stream: StreamType) throws {
        self.stream = stream
        try stream.connect()
    }
    
    deinit {
        try? stream.close()
    }

    public func respond(to request: Request) throws -> Response {
        try assertValid(request)
        guard !stream.isClosed else {
            throw ClientError.unableToConnect
        }

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
}

let VERSION = "2"
public var userAgent = "App (Swift) VaporEngine/\(VERSION)"


extension Client {
    internal func assertValid(_ request: Request) throws {
        if request.uri.hostname.isEmpty {
            guard request.uri.hostname == hostname else {
                throw ClientError.invalidRequestHost
            }
        }

        if request.uri.scheme.isEmpty {
            guard request.uri.scheme == scheme else {
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

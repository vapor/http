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

public typealias TCPClient = BasicClient<TCPInternetSocket>

import TLS

public typealias TLSClient = BasicClient<TLS.InternetSocket>

public final class BasicClient<StreamType: ClientStream>: Client {
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

        /// client MUST send a Host header field in all HTTP/1.1 request
        /// messages.  If the target URI includes an authority component, then a
        /// client MUST send a field-value for Host that is identical to that
        /// authority component, excluding any userinfo subcomponent and its "@"
        /// delimiter (Section 2.7.1).  If the authority component is missing or
        /// undefined for the target URI, then a client MUST send a Host header
        /// field with an empty field-value.
        request.headers["Host"] = stream.hostname
        request.headers["User-Agent"] = userAgent

        // let buffer = StreamBuffer<StreamType>(stream)
        let serializer = Serializer<StreamType>(stream: stream)
        try serializer.serialize(request)

        let parser = ResponseParser<StreamType>(stream: stream)
        let response = try parser.parse()

        response.peerAddress = parser.parsePeerAddress(
            from: stream,
            with: response.headers
        )

        // try buffer.flush()

        print("CLIENT DONE")
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
            guard request.uri.scheme.isSecure == scheme.isSecure else {
                throw ClientError.invalidRequestScheme
            }
        }

        if let requestPort = request.uri.port {
            guard requestPort == port else { throw ClientError.invalidRequestPort }
        }

        guard request.uri.userInfo == nil else {
            /// Userinfo (i.e., username and password) are now disallowed in HTTP and
            /// HTTPS URIs, because of security issues related to their transmission
            /// on the wire.  (Section 2.7.1)
            throw ClientError.userInfoNotAllowedOnHTTP
        }
    }
}

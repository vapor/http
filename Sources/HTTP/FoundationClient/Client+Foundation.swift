import Transport
import Foundation
import URI
//public enum ClientError: Swift.Error {
//    case invalidRequestHost
//    case invalidRequestScheme
//    case invalidRequestPort
//    case unableToConnect
//    case userInfoNotAllowedOnHTTP
//}
//
//let VERSION = "0.9.0"

class FauxStream: Transport.Stream {
    func setTimeout(_ timeout: Double) throws {
        fatalError("\(#function) not implemented")
    }

    var closed: Bool {
        fatalError("\(#function) not implemented")
    }

    func close() throws {
        fatalError("\(#function) not implemented")
    }

    func send(_ bytes: Bytes) throws {
        fatalError("\(#function) not implemented")
    }

    func flush() throws {
        fatalError("\(#function) not implemented")
    }

    func receive(max: Int) throws -> Bytes {
        fatalError("\(#function) not implemented")
    }

    // Optional, performance
    func receive() throws -> Byte? {
        fatalError("\(#function) not implemented")
    }

    /// The address of the remote end of the stream.
    /// Whatever makes sense in the context of the particular stream type.
    /// E.g. a IPv4 stream will have the concatination of the IP address
    /// and port: "10.0.0.130:63394"
    var peerAddress: String {
        fatalError("\(#function) not implemented")
    }
}

extension Request {
//    func makeFoundationRequest() throws -> URLRequest {
//        let urlReq = URLRequest(url: <#T##URL#>)
//
//        return urlReq
//    }
}

public final class FoundationClient: ClientProtocol {

    public let scheme: String
    public let host: String
    public let port: Int
    public let securityLayer: SecurityLayer
    public let middleware: [Middleware]

    let defaultSession = URLSession(configuration: .default)

    public let stream: Transport.Stream = FauxStream()

    private let responder: Responder

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

//        let client = try ClientStreamType(host: host, port: port, securityLayer: securityLayer)
//        let stream = try client.connect()
//        self.stream = stream

        let handler = Request.Handler { request in
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

//            let buffer = StreamBuffer(stream)
//            let serializer = SerializerType(stream: buffer)
//            try serializer.serialize(request)
//
//            let parser = ParserType(stream: buffer)
//            let response = try parser.parse()
//
//            try buffer.flush()

//            return response
            fatalError("\(#file):\(#line)")
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

    private func assertValid(_ request: Request) throws {
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

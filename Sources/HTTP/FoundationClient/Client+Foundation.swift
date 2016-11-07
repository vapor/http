import Transport
import Foundation
import URI
import Core

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
        print("\(#function) not implemented")
        return false
    }

    func close() throws {
        print("\(#function) not implemented")
    }

    func send(_ bytes: Bytes) throws {
        print("\(#function) not implemented")
    }

    func flush() throws {
        print("\(#function) not implemented")
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
        return "\(#function) not implemented"
    }
}

public final class FoundationClient: ClientProtocol {
    enum ResponderError: Error {
        case clientDeallocated
    }

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

        let session = URLSession(configuration: .default)
        let handler = Request.Handler { request in
            return try Portal.open { portal in
                let foundationRequest = try request.makeFoundationRequest()
                let task = session.dataTask(with: foundationRequest) { data, urlResponse, error in
                    if let error = error {
                        portal.close(with: error)
                        return
                    }

                    do {
                        let response = try Response(urlResponse: urlResponse, data: data)
                        portal.close(with: response)
                    } catch {
                        portal.close(with: error)
                    }
                }
                task.resume()
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

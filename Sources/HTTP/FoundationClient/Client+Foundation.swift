import Transport
import Foundation
import URI
import Core

/**
    This is here because it's a protocol requirement that we can't change now. 
    It allows us to satisfy Client goals and allow FoundationClient to function 
    using URLSession
*/
class FauxStream: Transport.Stream {
    func setTimeout(_ timeout: Double) throws {
        print("Faux stream does not support setting timeout. It is a dummy class to allow URLSession to work")
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
        fatalError("Faux stream does not support receiving. It is a dummy class to allow URLSession to work")
    }

    func receive() throws -> Byte? {
        fatalError("Faux stream does not support receiving. It is a dummy class to allow URLSession to work")
    }

    var peerAddress: String {
        return "\(#function) not implemented"
    }
}

public final class FoundationClient: ClientProtocol {
    public let scheme: String
    public let host: String
    public let port: Int
    public let securityLayer: SecurityLayer
    public let middleware: [Middleware]

    public let session: URLSession

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
        self.session = session
    }

    public func respond(to request: Request) throws -> Response {
        try assertValid(request)
        return try responder.respond(to: request)
    }
}

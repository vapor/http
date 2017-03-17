import Transport
import Foundation
import URI
import Core

/// This is here because it's a protocol requirement that we can't change now.
/// It allows us to satisfy Client goals and allow FoundationClient to function
/// using URLSession
public final class FoundationClientStream: InternetStream {
    public let scheme: String
    public let hostname: String
    public let port: Transport.Port
    public let session: URLSession

    public init(scheme: String, hostname: String, port: Transport.Port) {
        self.scheme = scheme
        self.hostname = hostname
        self.port = port
        self.session = URLSession(configuration: .default)
    }

    public func handle(_ request: Request) throws -> Response {
        return try Portal.open { portal in
            let foundationRequest = try request.makeFoundationRequest()
            let task = self.session.dataTask(with: foundationRequest) { data, urlResponse, error in
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
}

public final class FoundationClient: Client {
    public let stream: FoundationClientStream
    public let middleware: [Middleware]
    private let responder: Responder

    public init(
        _ stream: FoundationClientStream,
        _ middleware: [Middleware]
    ) throws {
        self.stream = stream
        self.middleware = type(of: self).defaultMiddleware + middleware

        let handler = Request.Handler { request in
            return try stream.handle(request)
        }

        // add middleware
        responder = self.middleware.chain(to: handler)
    }

    public func respond(to request: Request) throws -> Response {
        try assertValid(request)
        return try responder.respond(to: request)
    }
}

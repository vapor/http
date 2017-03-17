import Transport
import Foundation
import URI
import Core

public final class FoundationClient: Client {
    public let scheme: String
    public let hostname: String
    public let port: Transport.Port
    public let session: URLSession
    /// public let middleware: [Middleware]
    // private let responder: Responder

    public init(
        scheme: String,
        hostname: String,
        port: Transport.Port
    ) {
        self.scheme = scheme
        self.hostname = hostname
        self.port = port
        self.session = URLSession(configuration: .default)
        /// self.middleware = type(of: self).defaultMiddleware + middleware
    }

    public func respond(to request: Request) throws -> Response {
        try assertValid(request)

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

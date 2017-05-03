import Transport
import Foundation
import URI
import Core

/// client based on Foundation.URLRequest
/// and Foundation.URLSession
public final class FoundationClient: Client {
    public let scheme: String
    public let hostname: String
    public let port: Transport.Port
    public let session: URLSession

    /// create a new foundation client
    public init(
        scheme: String,
        hostname: String,
        port: Transport.Port
    ) {
        self.scheme = scheme
        self.hostname = hostname
        self.port = port
        self.session = URLSession(configuration: .default)
    }

    /// responds to the request using URLResponse
    public func respond(to request: Request, with writer: ResponseWriter) throws {
        try assertValid(request)

        let foundationRequest = try request.makeFoundationRequest()
        
        let task = self.session.dataTask(with: foundationRequest) { data, urlResponse, error in
            if let error = error {
                print(error)
            }

            // FIXME
            let response = try! Response(urlResponse: urlResponse, data: data)
            try! writer.write(response)
        }
        task.resume()
    }
}

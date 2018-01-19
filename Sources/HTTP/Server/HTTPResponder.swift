import Async

/// Converts HTTPRequests to future HTTPResponses on the supplied event loop.
public protocol HTTPResponder {
    /// Returns a future response for the supplied request.
    func respond(to req: HTTPRequest, on worker: Worker) throws -> Future<HTTPResponse>
}

extension HTTPResponder {
    /// Converts an HTTPResponder to an HTTPRequest -> HTTPResponse stream.
    public func stream(on worker: Worker) -> MapStream<HTTPRequest, HTTPResponse> {
        return MapStream { req in
            return try self.respond(to: req, on: worker)
        }
    }
}

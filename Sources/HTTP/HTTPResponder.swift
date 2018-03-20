/// Capable of responding to HTTP requests.
public protocol HTTPResponder {
    func respond(to request: HTTPRequest, on worker: Worker) -> Future<HTTPResponse>
}

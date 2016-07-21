public protocol HTTPResponder {
    func respond(to request: HTTPRequest) throws -> HTTPResponse
}

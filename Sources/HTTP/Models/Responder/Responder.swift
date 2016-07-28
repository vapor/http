public protocol Responder {
    func respond(to request: Request) throws -> Response
}

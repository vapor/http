public typealias Meddleware = Middleware

public protocol Middleware {
    func respond(to request: Request, chainingTo next: Responder) throws -> Response
}

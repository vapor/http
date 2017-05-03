public protocol Responder {
    func respond(to request: Request) throws -> Response 
}

public struct BasicResponder: Responder {
    public typealias Closure = (Request) throws -> Response
    let closure: Closure
    public init(_ closure: @escaping Closure) {
        self.closure = closure
    }
    
    public func respond(to request: Request) throws -> Response {
        return try self.closure(request)
    }
}


extension Request {
    public typealias Handler = BasicResponder
}

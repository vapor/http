import Dispatch

public protocol AsyncResponder {
    func respond(to request: Request, with writer: AsyncResponseWriter) throws
}

extension AsyncResponder {
    public func respondSync(to request: Request) throws -> Response {
        let semaphore = DispatchSemaphore(value: 0)
        var res: Response!
        
        try respond(to: request) { response in
            res = response
            semaphore.signal()
        }
        semaphore.wait()
        
        return res
    }
}

public struct BasicAsyncResponder: AsyncResponder {
    public typealias Closure = (Request, AsyncResponseWriter) throws -> ()
    let closure: Closure
    public init(_ closure: @escaping Closure) {
        self.closure = closure
    }
    
    public func respond(to request: Request, with writer: AsyncResponseWriter) throws {
        try self.closure(request, writer)
    }
}

extension AsyncResponder {
    func respond(to request: Request, with closure: @escaping (Response) throws -> ()) throws {
        let writer = BasicAsyncResponseWriter(closure)
        try self.respond(to: request, with: writer)
    }
}

public protocol AsyncResponseWriter {
    func write(_ response: Response) throws
}

extension AsyncResponseWriter {
    public func write(_ response: ResponseRepresentable) throws {
        let res = try response.makeResponse()
        try write(res)
    }
}

import Transport

public struct BasicAsyncResponseWriter: AsyncResponseWriter {
    public typealias Closure = (Response) throws -> ()
    
    let closure: Closure
    
    public init(_ closure: @escaping Closure) {
        self.closure = closure
    }
    
    public func write(_ response: Response) throws {
        try closure(response)
    }
}

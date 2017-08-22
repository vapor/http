import Core

/// 
public protocol RequestMiddleware : Core.Stream {
    associatedtype Input = Request
    associatedtype Output = Request
}

public protocol ResponseMiddleware : Core.Stream {
    associatedtype Input = Response
    associatedtype Output = Response
}

public protocol Middleware : Core.Stream {
    associatedtype Input = Request
    associatedtype Output = Response
}

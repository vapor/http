import URI
import Transport

private var _defaultMiddlewareStorage: [String: [Middleware]] = [:]

public protocol Program {
    associatedtype StreamType
    var stream: StreamType { get }
    var middleware: [Middleware] { get }
    init(_ stream: StreamType, _ middleware: [Middleware]) throws
    static var defaultMiddleware: [Middleware] { get set }
}

extension Program {
    public static var defaultMiddleware: [Middleware] {
        get {
            let name = "\(type(of: Self.self))"
            guard let middleware = _defaultMiddlewareStorage[name] else {
                _defaultMiddlewareStorage[name] = []
                return []
            }

            return middleware
        }

        set {
            let name = "\(type(of: Self.self))"
            _defaultMiddlewareStorage[name] = newValue
        }
    }
}

extension Program where StreamType: InternetStream {
    public init(
        scheme: String = "http",
        hostname: String = "0.0.0.0",
        port: Port = 80,
        _ middleware: [Middleware] = []
    ) throws {
        let stream = try StreamType(scheme: scheme, hostname: hostname, port: port)
        try self.init(stream, middleware)
    }
}

extension Stream where Self: InternetStream {
    public var address: String {
        return "\(hostname):\(port)"
    }
}

extension Stream where Self: Program, Self.StreamType: InternetStream {
    public var address: String {
        return "\(stream.hostname):\(stream.port)"
    }
}

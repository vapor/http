import URI
import Transport

private var _defaultMiddlewareStorage: [String: [Middleware]] = [:]

public protocol Program {
    var host: String { get }
    var port: Int { get }
    var securityLayer: SecurityLayer { get }
    var middleware: [Middleware] { get }
    init(host: String, port: Int, securityLayer: SecurityLayer, middleware: [Middleware]) throws
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

extension Program {
    public static func make(
        host: String? = nil,
        port: Int? = nil,
        securityLayer: SecurityLayer = .tls(nil),
        middleware: [Middleware] = []
    ) throws -> Self {
        let host = host ?? "0.0.0.0"
        let port = port ?? securityLayer.port()
        return try Self(host: host, port: port, securityLayer: securityLayer, middleware: Self.defaultMiddleware + middleware)
    }
}

extension SecurityLayer {
    func port() -> Int {
        switch self {
        case .none:
            return 80
        case .tls(_):
            return 443
        }
    }
}

extension Program {
    public static func make(
        scheme: String? = nil,
        host: String,
        port: Int? = nil,
        middleware: [Middleware] = []
    ) throws -> Self {
        let scheme = scheme ?? "https" // default to secure https connection
        let port = port ?? URI.defaultPorts[scheme] ?? 80
        return try Self(host: host, port: port, securityLayer: scheme.securityLayer, middleware: middleware)
    }
}

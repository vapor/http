import URI
import Transport

//private var _defaultMiddlewareStorage: [String: [Middleware]] = [:]
//
//public protocol Program {
//    var scheme: String { get }
//    var hostname: String { get }
//    var port: Port { get }
//    var middleware: [Middleware] { get }
//    init(scheme: String, hostname: String, port: Port, _ middleware: [Middleware]) throws
//    static var defaultMiddleware: [Middleware] { get set }
//}
//
//extension Program {
//    public static var defaultMiddleware: [Middleware] {
//        get {
//            let name = "\(type(of: Self.self))"
//            guard let middleware = _defaultMiddlewareStorage[name] else {
//                _defaultMiddlewareStorage[name] = []
//                return []
//            }
//
//            return middleware
//        }
//
//        set {
//            let name = "\(type(of: Self.self))"
//            _defaultMiddlewareStorage[name] = newValue
//        }
//    }
//}
//
//extension Program {
//    public init(
//        scheme: String = "http",
//        hostname: String = "0.0.0.0",
//        port: Port = 80
//    ) throws {
//        try self.init(
//            scheme: scheme,
//            hostname: hostname,
//            port: port,
//            []
//        )
//    }
//}
//
//
//
//extension Stream where Self: Program, Self.StreamType: InternetStream {
//    public var address: String {
//        return "\(stream.hostname):\(stream.port)"
//    }
//}

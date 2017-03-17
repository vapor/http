import Transport

public protocol Server: InternetStream {
    func start(_ responder: Responder, errors: @escaping ServerErrorHandler) throws
}

extension Server {
    public func start(_ responder: Responder) throws {
        try self.start(responder, errors: { _ in })
    }
}

//extension Server {
//    public static func start(
//        scheme: String = "http",
//        hostname: String = "0.0.0.0",
//        port: Port = 8080,
//        responder: Responder,
//        errors: @escaping ServerErrorHandler = { _ in }
//    ) throws {
//        let server = try Self.init(scheme: scheme, hostname: hostname, port: port)
//        let responder = responder
//        let errors = errors
//        try server.start(responder, errors: errors)
//    }
//}

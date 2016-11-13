import Transport

public protocol ServerProtocol: Program {
    func start(responder: Responder, errors: @escaping ServerErrorHandler) throws
    func startAsync(responder: Responder, errors: @escaping ServerErrorHandler) throws
}

extension ServerProtocol {

    public static func start(
        host: String? = nil,
        port: Int? = nil,
        securityLayer: SecurityLayer = .none,
        responder: Responder,
        errors: @escaping ServerErrorHandler
    ) throws {
        let server = try make(host: host, port: port, securityLayer: securityLayer)
        let responder = responder
        let errors = errors
        try server.start(responder: responder, errors: errors)
    }

    public static func startAsync(
        host: String? = nil,
        port: Int? = nil,
        securityLayer: SecurityLayer = .none,
        responder: Responder,
        errors: @escaping ServerErrorHandler
    ) throws -> Self {
        let server = try make(host: host, port: port, securityLayer: securityLayer)
        let responder = responder
        let errors = errors
        try server.startAsync(responder: responder, errors: errors)
        return server
    }
}

extension ServerProtocol {
    public func startAsync(responder: Responder, errors: @escaping ServerErrorHandler) throws {
        throw ServerError.notSupported
    }
}

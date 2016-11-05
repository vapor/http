#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

import Transport
import Dispatch

private let queue = DispatchQueue.global(qos: .userInteractive)

public typealias BasicServer = Server<TCPServerStream, Parser<Request>, Serializer<Response>>

public final class Server<
    ServerStreamType: ServerStream,
    Parser: TransferParser,
    Serializer: TransferSerializer>: ServerProtocol
    where
    Parser.MessageType == Request,
    Serializer.MessageType == Response
 {

    let server: ServerStreamType

    public let host: String
    public let port: Int
    public let securityLayer: SecurityLayer
    public let middleware: [Middleware]

    public init(
        host: String = "0.0.0.0",
        port: Int = 8080,
        securityLayer: SecurityLayer = .none,
        middleware: [Middleware] = []
    ) throws {
        self.host = host
        self.port = port
        self.securityLayer = securityLayer
        self.middleware = type(of: self).defaultMiddleware + middleware

        do {
            server = try ServerStreamType(host: host, port: port, securityLayer: securityLayer)
        } catch {
            throw ServerError.bind(host: host, port:port, error)
        }
    }

    public func start(responder: Responder, errors: @escaping ServerErrorHandler) throws {
        // add middleware
        let responder = middleware.chain(to: responder)

        // await connection attempts on the server socket
        try server.startWatching(on: queue) { [weak self] in
            guard let welf = self else { return }
            do {
                let stream = try welf.server.accept()
                try welf.respond(stream: stream, responder: responder, errors: errors)
            } catch {
                errors(.accept(error))
            }
        }
    }

    private func respond(stream: Stream, responder: Responder, errors: @escaping ServerErrorHandler) throws {
        let stream = StreamBuffer(stream)
        try stream.setTimeout(30)

        let parser = Parser(stream: stream)
        let serializer = Serializer(stream: stream)

        try stream.startWatching(on: queue) {
            do {
                let request = try parser.parse()
                let response = try responder.respond(to: request)
                try serializer.serialize(response)
                try response.onComplete?(stream)
                if !request.keepAlive {
                    try stream.close()
                }
            } catch ParserError.streamEmpty {
                // if stream is empty, it's time to
                // close the connection
                try? stream.close()
            } catch {
                errors(.respond(error))
            }
        }
    }
}

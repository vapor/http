#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

import Transport
import Dispatch

public var defaultServerTimeout: Double = 30

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
    private let queue = DispatchQueue(label: "codes.vapor.server", qos: .userInteractive, attributes: .concurrent)
    private let streams = ThreadsafeArray<StreamBuffer>()

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

    deinit {
        streams.forEach { stream in
            try? stream.close()
        }
    }

    public func start(responder: Responder, errors: @escaping ServerErrorHandler) throws {
        // add middleware
        let responder = middleware.chain(to: responder)

        // no throwing inside of the loop
        while true {
            let stream: Stream

            do {
                stream = try server.accept()
            } catch {
                errors(.accept(error))
                continue
            }

            queue.async {
                do {
                    try self.respond(stream: stream, responder: responder)
                } catch {
                    errors(.dispatch(error))
                }

            }
        }
    }

    private func respond(stream: Stream, responder: Responder) throws {
        let stream = StreamBuffer(stream)
        try stream.setTimeout(defaultServerTimeout)

        let parser = Parser(stream: stream)
        let serializer = Serializer(stream: stream)

        defer {
            try? stream.close()
        }

        var keepAlive = false
        repeat {
            let request: Request
            do {
                request = try parser.parse()
            } catch ParserError.streamEmpty {
                // if stream is empty, it's time to
                // close the connection
                break
            } catch {
                throw error
            }

            keepAlive = request.keepAlive
            let response = try responder.respond(to: request)
            try serializer.serialize(response)
            try response.onComplete?(stream)
        } while keepAlive && !stream.closed
    }

    public func startAsync(responder: Responder, errors: @escaping ServerErrorHandler) throws {
        // add middleware
        let responder = middleware.chain(to: responder)
        
        // await connection attempts on the server socket
        try server.startWatching(on: queue) { [weak self] in
            guard let welf = self else { return }
            do {
                let stream = try welf.server.accept()
                let bufferedStream = StreamBuffer(stream)
                welf.streams.append(bufferedStream)
                try welf.respondAsync(stream: bufferedStream, responder: responder, errors: errors)
            } catch {
                errors(.accept(error))
            }
        }
    }

    private func respondAsync(stream: StreamBuffer, responder: Responder, errors: @escaping ServerErrorHandler) throws {
        let parser = Parser(stream: stream)
        let serializer = Serializer(stream: stream)
        
        // await data on `stream`
        try stream.startWatching(on: queue) { [weak self] in
            // stream, parser and serializer are retained by the closure.
            // when the stream is closed, watching stops and the closure is released.
            do {
                let request = try parser.parse()
                let response = try responder.respond(to: request)
                try serializer.serialize(response)
                try response.onComplete?(stream)
                if !request.keepAlive {
                    self?.streams.remove(stream)
                    try stream.close()
                }
            } catch ParserError.streamEmpty {
                self?.streams.remove(stream)
                try? stream.close()
            } catch let error where error is StreamError {
                // if there's a problem with the stream, there's no point in keeping it open.
                self?.streams.remove(stream)
                try? stream.close()
                // reporting the error is not strictly necessary here (there are  legitimate
                // reasons for socket connections to be broken), but helpful for debugging.
                errors(.respond(error))
            } catch {
                errors(.respond(error))
            }
        }
    }
}

import libc
import Transport
import Dispatch
import Sockets
import TLS

public var defaultServerTimeout: Double = 30

public typealias TCPServer = BasicServer<TCPInternetSocket>


public typealias TLSServer = BasicServer<TLS.InternetSocket>

public final class BasicServer<StreamType: ServerStream>: Server {
    public let stream: StreamType
    public let listenMax: Int

    public var scheme: String {
        return stream.scheme
    }

    public var hostname: String {
        return stream.hostname
    }

    public var port: Port {
        return stream.port
    }

    public init(_ stream: StreamType, listenMax: Int = 128) throws {
        self.stream = stream
        self.listenMax = listenMax
    }

    private let queue = DispatchQueue(
        label: "codes.vapor.server",
        qos: .userInteractive,
        attributes: .concurrent
    )

    public func start(_ responder: Responder, errors: @escaping ServerErrorHandler) throws {
        try stream.bind()
        try stream.listen(max: listenMax)

        // no throwing inside of the loop
        while true {
            let client: StreamType.Client

            do {
                client = try stream.accept()
            } catch {
                errors(.accept(error))
                continue
            }

            queue.async {
                do {
                    try self.respond(stream: client, responder: responder)
                } catch {
                    errors(.dispatch(error))
                }

            }
        }
    }

    private func respond(stream: StreamType.Client, responder: Responder) throws {
        try stream.setTimeout(defaultServerTimeout)

        let parser = RequestParser()
        let serializer = ResponseSerializer<StreamType.Client>(stream)

        defer {
            try? stream.close()
        }

        var keepAlive = false
        repeat {
            let request: Request
            do {
                // FIXME
                var bytes = try stream.read(max: 2048)
                request = try parser.parse(from: &bytes, length: bytes.count)!
            } catch ParserError.streamClosed {
                break
            } catch {
                throw error
            }
            
            // set the stream for peer information
            request.stream = stream

            keepAlive = request.keepAlive
            let response = try responder.respondSync(to: request)
            try serializer.serialize(response)
            try response.onComplete?(stream)
        } while keepAlive && !stream.isClosed
    }
}

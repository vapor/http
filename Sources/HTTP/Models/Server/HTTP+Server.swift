import libc
import Transport
import Dispatch
import Sockets
import TLS

public var defaultServerTimeout: Double = 30

public typealias TCPServer = BasicServer<
    TCPInternetSocket,
    Parser<Request, StreamBuffer<TCPInternetSocket>>,
    Serializer<Response, StreamBuffer<TCPInternetSocket>>
>


public typealias TLSServer = BasicServer<
    TLS.InternetSocket,
    Parser<Request, StreamBuffer<TLS.InternetSocket>>,
    Serializer<Response, StreamBuffer<TLS.InternetSocket>>
>

public final class BasicServer<
    StreamType: ServerStream,
    Parser: TransferParser,
    Serializer: TransferSerializer
>: Server where
    Parser.MessageType == Request,
    Serializer.MessageType == Response,
    Parser.StreamType == StreamBuffer<StreamType.Client>,
    Serializer.StreamType == StreamBuffer<StreamType.Client>
 {
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

    public init(_ stream: StreamType, listenMax: Int = 4096) throws {
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

            request.peerAddress = parser.parsePeerAddress(
                from: self.stream,
                with: request.headers
            )

            keepAlive = request.keepAlive
            let response = try responder.respond(to: request)
            try serializer.serialize(response)
            try response.onComplete?(stream)
        } while keepAlive && !stream.isClosed
    }
}

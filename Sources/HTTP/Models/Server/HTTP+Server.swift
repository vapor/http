import libc
import Transport
import Dispatch
import Sockets

public var defaultServerTimeout: Double = 30

public typealias TCPServer = BasicServer<
    TCPInternetSocket,
    Parser<Request, StreamBuffer<TCPInternetSocket>>,
    Serializer<Response, StreamBuffer<TCPInternetSocket>>
>

import TLS

public typealias TLSTCPServer = BasicServer<
    TLS.ServerSocket,
    Parser<Request, StreamBuffer<TLS.ServerSocket>>,
    Serializer<Response, StreamBuffer<TLS.ServerSocket>>
>

public final class BasicServer<
    ServerStreamType: ServerStream,
    Parser: TransferParser,
    Serializer: TransferSerializer
>: Server where
    Parser.MessageType == Request,
    Serializer.MessageType == Response,
    Parser.StreamType == StreamBuffer<ServerStreamType>,
    Serializer.StreamType == StreamBuffer<ServerStreamType>
 {
    public typealias StreamType = ServerStreamType

    private let queue = DispatchQueue(label: "codes.vapor.server", qos: .userInteractive, attributes: .concurrent)
    private let streams = ThreadsafeArray<StreamBuffer<StreamType>>()

    public let middleware: [Middleware]
    public let stream: StreamType

    public init(
        _ stream: StreamType,
        _ middleware: [Middleware] = []
    ) throws {
        self.stream = stream
        self.middleware = type(of: self).defaultMiddleware + middleware
    }

    deinit {
        streams.forEach { stream in
            try? stream.close()
        }
    }

    public func start(_ responder: Responder, errors: @escaping ServerErrorHandler) throws {
        // add middleware
        let responder = middleware.chain(to: responder)

        try stream.bind()
        try stream.listen(max: 4096)

        // no throwing inside of the loop
        while true {
            let client: ServerStreamType

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

    private func respond(stream: ServerStreamType, responder: Responder) throws {
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

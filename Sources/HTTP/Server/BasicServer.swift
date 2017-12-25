import libc
import Transport
import Foundation
import Dispatch
import Sockets
import TLS

public var defaultServerTimeout: Double = 30

public final class BasicServer<StreamType: ServerStream>: Server {
    public let stream: StreamType
    public let listenMax: Int

    public var scheme: String {
        return stream.scheme
    }

    public var hostname: String {
        return stream.hostname
    }

    public var port: Transport.Port {
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
        
        var buffer = Bytes(repeating: 0, count: 2048)

        let parser = RequestParser()
        let serializer = ResponseSerializer()

        defer {
            try? stream.close()
        }

        var keepAlive = false
        main: repeat {
            var request: Request?
            
            while request == nil {
                let read = try stream.read(max: buffer.count, into: &buffer)
                guard read > 0 else {
                    break main
                }
                request = try parser.parse(max: read, from: buffer)
            }
            
            guard let req = request else {
                // FIXME: better error
                print("Could not parse a request from the stream")
                throw ParserError.invalidMessage
            }
            
            // set the stream for peer information
            req.stream = stream

            keepAlive = req.keepAlive
            let response = try responder.respond(to: req)

            var responseData = DispatchData.empty
            
            while true {
                let length = try serializer.serialize(response, into: &buffer)
                guard length > 0 else {
                    break
                }
                let buffer = UnsafeRawBufferPointer(
                    start: &buffer,
                    count: length
                )
                let data = DispatchData(bytes: buffer)
                responseData.append(data)
            }

            switch response.body {
            case .chunked(_):
                break
            case .data(var bytes):
                let buffer = UnsafeRawBufferPointer(
                    start: &bytes,
                    count: bytes.count
                )
                let data = DispatchData(bytes: buffer)
                responseData.append(data)
            }


            let copied = Data(responseData)
            let buffer = UnsafeBufferPointer<Byte>(
                start: copied.withUnsafeBytes { $0 },
                count: copied.count
            )
            let bytes = Bytes(buffer)
            let written = try stream.write(max: bytes.count, from: bytes)

            guard written == bytes.count else {
                // FIXME: better error
                print("Could not write all bytes to the stream")
                throw StreamError.closed
            }

            switch response.body {
            case .chunked(let closure):
                let chunk = ChunkStream(stream)
                try closure(chunk)
            case .data(_):
                break
            }

            
            try response.onComplete?(stream)
        } while keepAlive && !stream.isClosed
    }
}

extension DispatchData {
    static let empty = DispatchData(bytes: UnsafeRawBufferPointer(start: nil, count: 0))
}

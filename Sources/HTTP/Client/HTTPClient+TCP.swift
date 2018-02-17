import Async
import TCP

extension HTTPClient {
    /// Create a TCP-based HTTP client. See `TCPClient`.
    public static func tcp(
        hostname: String,
        port: UInt16,
        on worker: Worker,
        onError: @escaping TCPSocketSink.ErrorHandler
    ) throws -> HTTPClient {
        let tcpSocket = try TCPSocket(isNonBlocking: true)
        let tcpClient = try TCPClient(socket: tcpSocket)
        try tcpClient.connect(hostname: hostname, port: port)
        let stream = tcpSocket.stream(on: worker, onError: onError)
        return HTTPClient(stream: stream, on: worker)
    }
}


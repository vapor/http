import Async
import TCP

extension HTTPClient {
    /// Create a TCP-based HTTP client. See `TCPClient`.
    public static func tcp(hostname: String, port: UInt16, on worker: Worker) throws -> HTTPClient {
        let tcpSocket = try TCPSocket(isNonBlocking: true)
        let tcpClient = try TCPClient(socket: tcpSocket)
        try tcpClient.connect(hostname: "httpbin.org", port: 80)
        return HTTPClient(stream: tcpSocket.stream(on: worker), on: worker)
    }
}

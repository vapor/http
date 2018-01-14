import Async
import TCP

extension HTTPClient {
    /// Create a TCP-based HTTP client. See `TCPClient`.
    public static func tcp(hostname: String, port: UInt16, on worker: Worker) throws -> HTTPClient {
        let tcpSocket = try TCPSocket(isNonBlocking: true)
        let tcpClient = try TCPClient(socket: tcpSocket)
        try tcpClient.connect(hostname: "httpbin.org", port: 80)
        let tcpSource = tcpSocket.source(on: worker)
        let tcpSink = tcpSocket.sink(on: worker)
        return HTTPClient(source: tcpSource, sink: tcpSink, worker: worker)
    }
}

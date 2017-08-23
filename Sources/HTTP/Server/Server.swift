import Core
import TCP

/// HTTP server wrapped around TCP server
public final class Server: Core.OutputStream {
    // MARK: Stream
    public typealias Output = HTTP.Client
    public var errorStream: ErrorHandler?
    public var outputStream: OutputHandler?

    public let server: TCP.Server

    public init(server: TCP.Server) {
        self.server = server
        server.outputStream = { tcp in
            let client = HTTP.Client(client: tcp)
            self.outputStream?(client)
        }
    }
}

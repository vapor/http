import Async
import COperatingSystem

/// Stream representation of a TCP server.
public final class TCPClientStream: OutputStream, ConnectionContext {
    /// See OutputStream.Output
    public typealias Output = TCPClient

    /// The server being streamed
    public var server: TCPServer

    /// This stream's event loop
    public let eventLoop: EventLoop

    /// Downstream client and eventloop input stream
    private var downstream: AnyInputStream<Output>?

    /// The amount of requested output remaining
    private var requestedOutputRemaining: UInt

    /// Keep a reference to the read source so it doesn't deallocate
    private var acceptSource: EventSource?

    /// Use TCPServer.stream to create
    internal init(server: TCPServer, on eventLoop: EventLoop) {
        self.eventLoop = eventLoop
        self.server = server
        self.requestedOutputRemaining = 0
        let source = eventLoop.onReadable(descriptor: server.socket.descriptor, accept)
        source.resume()
        acceptSource = source
    }

    /// See OutputStream.output
    public func output<S>(to inputStream: S) where S: InputStream, S.Input == Output {
        downstream = AnyInputStream(inputStream)
        inputStream.connect(to: self)
    }

    /// See ConnectionContext.connection
    public func connection(_ event: ConnectionEvent) {
        switch event {
        case.request(let count):
            /// handle downstream requesting data
            /// suspend will be called automatically if the
            /// remaining requested output count ever
            /// reaches zero.
            /// the downstream is expected to continue
            /// requesting additional output as it is ready.
            /// the server will automatically resume if
            /// additional clients are requested after
            /// suspend has been called
            self.request(count)
        case .cancel:
            /// handle downstream canceling output requests
            self.cancel()
        }
    }

    /// Resumes accepting clients if currently suspended
    /// and count is greater than 0
    private func request(_ accepting: UInt) {
        assert(accepting == .max)
    }

    /// Cancels the stream
    private func cancel() {
        server.stop()
        downstream?.close()
        acceptSource = nil
    }

    /// Accepts a client and outputs to the stream
    private func accept(isCancelled: Bool) {
        do {
            guard let client = try server.accept() else {
                // the client was rejected or not available
                return
            }
            downstream?.next(client)
        } catch {
            downstream?.error(error)
        }
    }
}

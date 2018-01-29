import Async
import Bits

/// Streams ByteBuffers parsed by CHTTP during `on_message` callbacks.
final class CHTTPBodyStream: OutputStream {
    /// See `OutputStream.Output`
    typealias Output = ByteBuffer

    /// Creates a new `CHTTPBodyStream`
    init() {}

    /// Current downstream accepting the body's byte buffers.
    var downstream: AnyInputStream<ByteBuffer>?

    /// Waiting output
    var waiting: (ByteBuffer, Promise<Void>)?

    /// Pushes a new ByteBuffer with associated ready.
    func push(_ buffer: ByteBuffer, _ ready: Promise<Void>) {
        assert(waiting == nil)
        if let downstream = self.downstream {
            downstream.input(.next(buffer, ready))
        } else {
            waiting = (buffer, ready)
        }
    }

    /// See `OutputStream.output(to:)`
    func output<S>(to inputStream: S) where S : InputStream, CHTTPBodyStream.Output == S.Input {
        downstream = .init(inputStream)
        if let (buffer, ready) = self.waiting {
            self.waiting = nil
            inputStream.input(.next(buffer, ready))
        }
    }

    /// Closes the stream.
    func close() {
        downstream!.close()
    }
}

import Async
import Bits
import Foundation

/// Streams ByteBuffers parsed by CHTTP during `on_message` callbacks.
final class CHTTPBodyStream: Async.OutputStream {
    /// See `OutputStream.Output`
    typealias Output = ByteBuffer

    /// Creates a new `CHTTPBodyStream`
    init() {}

    /// Current downstream accepting the body's byte buffers.
    var downstream: AnyInputStream<ByteBuffer>?

    /// Waiting data
    private var waitingData: Data?

    /// Waiting ready
    private var waitingReady: Promise<Void>?

    /// Pushes a new ByteBuffer with associated ready.
    func push(_ buffer: ByteBuffer) {
        if var data = waitingData {
            data.append(buffer)
            waitingData = data
        } else {
            waitingData = Data(buffer)
        }
    }

    func flush(_ ready: Promise<Void>) {
        if let downstream = self.downstream {
            if let data = waitingData {
                waitingData = nil
                data.withByteBuffer { downstream.input(.next($0, ready)) }
            } else {
                // send empty data
                Data().withByteBuffer { downstream.input(.next($0, ready)) }
            }
        } else {
            waitingReady = ready
        }
    }

    /// See `OutputStream.output(to:)`
    func output<S>(to inputStream: S) where S: Async.InputStream, CHTTPBodyStream.Output == S.Input {
        downstream = .init(inputStream)
        if let ready = waitingReady {
            waitingReady = nil
            flush(ready)
        }
    }

    /// Closes the stream.
    func close() {
        DEBUG("CHTTPBodyStream.close()")
        assert(downstream != nil)
        downstream?.close()
    }
}



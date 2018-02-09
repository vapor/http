import Async
import Bits
import Foundation

/// Applies HTTP/1 chunk encoding to a stream of data
final class HTTPChunkEncodingStream: Async.Stream {
    /// See InputStream.Input
    typealias Input = ByteBuffer
    
    /// See OutputStream.Output
    typealias Output = ByteBuffer
    
    /// Remaining requested output
    private var remainingOutputRequested: UInt
    
    /// The downstream input stream.
    private var downstream: AnyInputStream<ByteBuffer>?
    
    /// If true, the chunk encoder has been closed.
    var closeState: CloseState = .notClosing
    var chunk: Data?
    
    enum CloseState {
        case notClosing, closing, closed
    }
    
    var isClosed: Bool {
        didSet {
            if isClosed {
                self.closeState = .closing
            } else {
                self.closeState = .notClosing
            }
        }
    }
    var headers = HTTPHeaders()
    
    /// Create a new chunk encoding stream
    init() {
        remainingOutputRequested = 0
        isClosed = false
    }
    
    /// See InputStream.input
    func input(_ event: InputEvent<ByteBuffer>) {
        switch event {
        case .next(let input, let done):
            // FIXME: Improve performance
            let hexNumber = String(input.count, radix: 16, uppercase: true).data(using: .utf8)!
            self.chunk = hexNumber + crlf + Data(input) + crlf
            self.chunk!.withByteBuffer { downstream!.input(.next($0, done)) }
        case .error(let error):
            downstream?.error(error)
        case .close:
            isClosed = true
            let promise = Promise(Void.self)
            eof.withByteBuffer { downstream?.input(.next($0, promise)) }
            downstream?.close()
        }
    }
    
    /// See OutputStream.output(to:)
    func output<I>(to inputStream: I) where I : Async.InputStream, Output == I.Input {
        downstream = AnyInputStream(inputStream)
    }
}

private let crlf = Data([.carriageReturn, .newLine])
private let eof = Data([.zero]) +  crlf + crlf


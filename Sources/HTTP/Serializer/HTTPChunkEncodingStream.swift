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
            downstream!.next(self.chunk!.withByteBuffer { $0 }, done)
        case .error(let error):
            downstream?.error(error)
        case .close:
            isClosed = true
            /// FIXME: send closing chunk
        }
    }
    
    /// See OutputStream.output(to:)
    func output<I>(to inputStream: I) where I : Async.InputStream, Output == I.Input {
        downstream = AnyInputStream(inputStream)
    }
    
//    /// Update the chunk encoders state
//    private func update() {
//        if remainingOutputRequested > 0 {
//            guard let downstream = downstream else {
//                return
//            }
//
//            switch closeState {
//            case .notClosing:
//                if let chunk = self.chunk {
//                    remainingOutputRequested -= 1
//                    chunk.withByteBuffer(downstream.next)
//                }
//            case .closing:
//                self.closeState = .closed
//                self.remainingOutputRequested -= 1
//                eof.withByteBuffer(downstream.next)
//            case .closed:
//                downstream.close()
//            }
//        }
//    }
}

private let crlf = Data([.carriageReturn, .newLine])
private let eof = Data([.zero]) +  crlf + crlf


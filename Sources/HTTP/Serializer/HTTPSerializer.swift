import Async
import Bits
import Dispatch
import Foundation

/// A helper for Request and Response serializer that keeps state
indirect enum HTTPSerializerState {
    case startLine
    case headers
    case body
    case done
    case continueBuffer(ByteBuffer, nextState: HTTPSerializerState)
    case streaming(AnyOutputStream<ByteBuffer>)
}

public final class HTTPSerializerContext {
    var state: HTTPSerializerState

    private let buffer: MutableByteBuffer
    private var bufferOffset: Int

    func drain() -> ByteBuffer {
        defer { bufferOffset = 0 }
        return ByteBuffer(start: buffer.baseAddress, count: bufferOffset)
    }

    init() {
        let bufferSize: Int = 2048
        bufferOffset = 0
        let pointer = MutableBytesPointer.allocate(capacity: bufferSize)
        self.buffer = MutableByteBuffer(start: pointer, count: bufferSize)
        self.state = .startLine
    }

    func append(_ data: ByteBuffer) -> ByteBuffer? {
        let writeSize = min(data.count, buffer.count - bufferOffset)
        memcpy(buffer.baseAddress!.advanced(by: bufferOffset), data.baseAddress!, writeSize)
        bufferOffset += writeSize
        guard writeSize >= data.count else {
            return ByteBuffer(start: data.baseAddress!.advanced(by: writeSize), count: data.count - writeSize)
        }
        return nil
    }

    deinit {
        buffer.baseAddress?.deinitialize()
        buffer.baseAddress?.deallocate(capacity: buffer.count)
    }
}

/// Internal Swift HTTP serializer protocol.
public protocol HTTPSerializer: Async.Stream where Input: HTTPMessage, Output == ByteBuffer {
    var context: HTTPSerializerContext { get }
    var downstream: AnyInputStream<ByteBuffer>? { get set }
    func serializeStartLine(for message: Input) -> ByteBuffer
}

extension HTTPSerializer {
    public func input(_ event: InputEvent<Input>) {
        guard let downstream = self.downstream else {
            fatalError()
        }
        switch event {
        case .close: downstream.close()
        case .error(let e): downstream.error(e)
        case .next(let input, let ready):
            try! serialize(input, downstream, ready)
        }
    }

    public func output<S>(to inputStream: S) where S: Async.InputStream, HTTPRequestSerializer.Output == S.Input {
        downstream = .init(inputStream)
    }

    fileprivate func serialize(_ message: Input, _ downstream: AnyInputStream<ByteBuffer>, _ nextMessage: Promise<Void>) throws {
        switch context.state {
        case .startLine:
            if let remaining = context.append(serializeStartLine(for: message)) {
                context.state = .continueBuffer(remaining, nextState: .headers)
                write(message, downstream, nextMessage)
            } else {
                context.state = .headers
                try serialize(message, downstream, nextMessage)
            }
        case .headers:
            let buffer = message.headers.storage.withByteBuffer { $0 }
            if let remaining = context.append(buffer) {
                context.state = .continueBuffer(remaining, nextState: .body)
                write(message, downstream, nextMessage)
            } else {
                context.state = .body
                try serialize(message, downstream, nextMessage)
            }
        case .body:
            let byteBuffer: ByteBuffer?

            switch message.body.storage {
            case .data(let data):
                byteBuffer = ByteBuffer(start: data.withUnsafeBytes { $0 }, count: data.count)
            case .dispatchData(let data):
                byteBuffer = ByteBuffer(start: data.withUnsafeBytes { $0 }, count: data.count)
            case .staticString(let staticString):
                byteBuffer = ByteBuffer(start: staticString.utf8Start, count: staticString.utf8CodeUnitCount)
            case .string(let string):
                let bytePointer = string.withCString { pointer in
                    return pointer.withMemoryRebound(to: UInt8.self, capacity: string.utf8.count) { $0 }
                }
                byteBuffer = ByteBuffer(start: bytePointer, count: string.utf8.count)
            case .buffer(let buffer):
                byteBuffer = buffer
            case .none:
                byteBuffer = nil
            case .chunkedOutputStream(_), .binaryOutputStream(_):
                byteBuffer = nil
            }

            if let buffer = byteBuffer {
                if let remaining = context.append(buffer) {
                    context.state = .continueBuffer(remaining, nextState: .done)
                    write(message, downstream, nextMessage)
                } else {
                    context.state = .done
                    write(message, downstream, nextMessage)
                }
            } else {
                switch message.body.storage {
                case .none:
                    context.state = .done
                    write(message, downstream, nextMessage)
                case .chunkedOutputStream(let stream):
                    let encodedStream = stream(HTTPChunkEncodingStream())
                    context.state = .streaming(AnyOutputStream(encodedStream))
                    write(message, downstream, nextMessage)
                case .binaryOutputStream(_, let stream):
                    let connectingStream = stream.stream(to: ConnectingStream<ByteBuffer>())
                    context.state = .streaming(AnyOutputStream(connectingStream))
                    write(message, downstream, nextMessage)
                default: fatalError()
                }
            }
        case .continueBuffer(let remainingStartLine, let then):
            if let remaining = context.append(remainingStartLine) {
                context.state = .continueBuffer(remaining, nextState: then)
                write(message, downstream, nextMessage)
            } else {
                context.state = then
                try serialize(message, downstream, nextMessage)
            }
        case .streaming(let stream):
            write(message, stream, downstream, nextMessage, .done)
        case .done:
            context.state = .startLine
            nextMessage.complete()
        }
    }
    
    fileprivate func write(_ message: Input, _ upstream: AnyOutputStream<Output>, _ downstream: AnyInputStream<Output>, _ nextMessage: Promise<Void>, _ nextState: HTTPSerializerState) {
        
        let peekStream = PeekStream<Output>()
        
        peekStream.onClose = {
            do {
                self.context.state = nextState
                try self.serialize(message, downstream, nextMessage)
            } catch {
                downstream.error(error)
            }
        }
        
        upstream.stream(to: peekStream).output(to: downstream)
    }

    fileprivate func write(_ message: Input, _ downstream: AnyInputStream<Output>, _ nextMessage: Promise<Void>) {
        let promise = Promise(Void.self)
        downstream.input(.next(context.drain(), promise))
        promise.future.addAwaiter { result in
            switch result {
            case .error(let error): downstream.error(error)
            case .expectation:
                do {
                    try self.serialize(message, downstream, nextMessage)
                } catch {
                    downstream.error(error)
                }
            }
        }
    }
}

fileprivate final class PeekStream<Data>: Async.Stream {
    typealias Input = Data
    typealias Output = Data
    
    var onClose: (()->())?
    var downstream: AnyInputStream<Data>?
    
    func input(_ event: InputEvent<Input>) {
        downstream?.input(event)
        
        switch event {
        case .close:
            onClose?()
        default: return
        }
    }
    
    func output<S>(to inputStream: S) where S : Async.InputStream, Output == S.Input {
        self.downstream = AnyInputStream(inputStream)
    }
}

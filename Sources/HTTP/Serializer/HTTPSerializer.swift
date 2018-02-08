import Async
import Bits
import Dispatch
import Foundation

/// A helper for Request and Response serializer that keeps state
public indirect enum HTTPSerializerState {
    case startLine
    case headers
    case body
    case done
    case continueBuffer(ByteBuffer, nextState: HTTPSerializerState)
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
        self.buffer = MutableByteBuffer.allocate(capacity: bufferSize)
        self.state = .startLine
    }

    func append(_ data: ByteBuffer) -> ByteBuffer? {
        let writeSize = min(data.count, buffer.count - bufferOffset)
        buffer.baseAddress!.advanced(by: bufferOffset).initialize(from: data.baseAddress!, count: writeSize)
        bufferOffset += writeSize
        guard writeSize >= data.count else {
            return ByteBuffer(start: data.baseAddress!.advanced(by: writeSize), count: data.count - writeSize)
        }
        return nil
    }

    deinit {
        if case .continueBuffer(let continueBuffer, _) = state {
            continueBuffer.deallocate()
        }
        buffer.deallocate()
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
                context.state = .continueBuffer(remaining.allocateAndInitializeCopy(), nextState: .headers)
                write(message, downstream, nextMessage)
            } else {
                context.state = .headers
                try serialize(message, downstream, nextMessage)
            }
        case .headers:
            if let remaining = message.headers.storage.withByteBuffer({ context.append($0) }) {
                context.state = .continueBuffer(remaining.allocateAndInitializeCopy(), nextState: .body)
                write(message, downstream, nextMessage)
            } else {
                context.state = .body
                try serialize(message, downstream, nextMessage)
            }
        case .body:
            let byteBuffer: ByteBuffer?
            
            func sendDownstream(buffer: ByteBuffer) {
                if let remaining = context.append(buffer) {
                    // Unfortunately, because we can't allow the buffer's pointer
                    // to escape the current context if we don't maange it, we have
                    // no choice but to copy here. 99% of the time, it will appear
                    // to work without copying, but then it'll bug out horribly when
                    // you least expect it.
                    context.state = .continueBuffer(remaining.allocateAndInitializeCopy(), nextState: .done)
                    write(message, downstream, nextMessage)
                } else {
                    context.state = .done
                    write(message, downstream, nextMessage)
                }
            }
            
            switch message.body.storage {
            case .data(let data):
                let count = data.count
                data.withUnsafeBytes { sendDownstream(buffer: ByteBuffer(start: $0, count: count)) }
            case .dispatchData(let data):
                let count = data.count
                data.withUnsafeBytes { sendDownstream(buffer: ByteBuffer(start: $0, count: count)) }
            case .staticString(let staticString):
                staticString.withUTF8Buffer { $0.withMemoryRebound(to: Byte.self) {
                    sendDownstream(buffer: ByteBuffer(start: $0.baseAddress!, count: $0.count))
                }}
            case .string(let string):
                let count = string.utf8.count
                string.withCString { $0.withMemoryRebound(to: Byte.self, capacity: count) {
                    sendDownstream(buffer: ByteBuffer(start: $0, count: count))
                }}
            case .buffer(let buffer):
                sendDownstream(buffer: buffer)
            case .none:
                context.state = .done
                write(message, downstream, nextMessage)
            case .chunkedOutputStream(_), .binaryOutputStream(_):
                fatalError()
            }
        case .continueBuffer(let remainingStartLine, let then):
            if let remaining = context.append(remainingStartLine) {
                context.state = .continueBuffer(remaining.allocateAndInitializeCopy(), nextState: then)
                write(message, downstream, nextMessage)
            } else {
                context.state = then
                try serialize(message, downstream, nextMessage)
            }
            remainingStartLine.deallocate()
        case .done:
            context.state = .startLine
            nextMessage.complete()
        }
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

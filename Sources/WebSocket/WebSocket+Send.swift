import libc
import Core

public final class FrameSerializer : Core.Stream {
    public typealias Input = Frame
    
    // TODO: Is this a good idea?
    public typealias Output = ByteBuffer
    
    public var outputStream: OutputHandler?
    public var errorStream: ErrorHandler?
    
    public func inputStream(_ input: Frame) {
        outputStream?(ByteBuffer(start: input.buffer.baseAddress, count: input.buffer.count))
    }
}

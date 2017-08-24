import libc
import Core

public final class FrameSerializer : Core.Stream {
    public typealias Input = Frame
    
    // TODO: Is this a good idea?
    public typealias Output = ByteBuffer
    
    public var outputStream: OutputHandler?
    public var errorStream: ErrorHandler?
    
    public func inputStream(_ input: Frame) {
        input.mask()
        outputStream?(ByteBuffer(start: input.buffer.baseAddress, count: input.buffer.count))
    }
    
    let mask: Bool
    
    init(masking: Bool) {
        self.mask = masking
    }
}

func randomMask() -> [UInt8] {
    var buffer: [UInt8] = [0,0,0,0]
    
    var number: UInt32
    
    #if os(Linux)
        number = numericCast(libc.random() % UInt32.max)
    #else
        number = arc4random_uniform(UInt32.max)
    #endif
    
    memcpy(&buffer, &number, 4)
    
    return buffer
}
